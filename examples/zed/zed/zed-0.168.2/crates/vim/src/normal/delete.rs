use crate::{motion::Motion, object::Object, Vim};
use collections::{HashMap, HashSet};
use editor::{
    display_map::{DisplaySnapshot, ToDisplayPoint},
    scroll::Autoscroll,
    Bias, DisplayPoint,
};
use language::{Point, Selection};
use multi_buffer::MultiBufferRow;
use ui::ViewContext;

impl Vim {
    pub fn delete_motion(
        &mut self,
        motion: Motion,
        times: Option<usize>,
        cx: &mut ViewContext<Self>,
    ) {
        self.stop_recording(cx);
        self.update_editor(cx, |vim, editor, cx| {
            let text_layout_details = editor.text_layout_details(cx);
            editor.transact(cx, |editor, cx| {
                editor.set_clip_at_line_ends(false, cx);
                let mut original_columns: HashMap<_, _> = Default::default();
                editor.change_selections(Some(Autoscroll::fit()), cx, |s| {
                    s.move_with(|map, selection| {
                        let original_head = selection.head();
                        original_columns.insert(selection.id, original_head.column());
                        motion.expand_selection(map, selection, times, true, &text_layout_details);

                        let start_point = selection.start.to_point(map);
                        let next_line = map
                            .buffer_snapshot
                            .clip_point(Point::new(start_point.row + 1, 0), Bias::Left)
                            .to_display_point(map);
                        match motion {
                            // Motion::NextWordStart on an empty line should delete it.
                            Motion::NextWordStart { .. }
                                if selection.is_empty()
                                    && map
                                        .buffer_snapshot
                                        .line_len(MultiBufferRow(start_point.row))
                                        == 0 =>
                            {
                                selection.end = next_line
                            }
                            // Sentence motions, when done from start of line, include the newline
                            Motion::SentenceForward | Motion::SentenceBackward
                                if selection.start.column() == 0 =>
                            {
                                selection.end = next_line
                            }
                            Motion::EndOfDocument {} => {
                                // Deleting until the end of the document includes the last line, including
                                // soft-wrapped lines.
                                selection.end = map.max_point()
                            }
                            _ => {}
                        }
                    });
                });
                vim.copy_selections_content(editor, motion.linewise(), cx);
                editor.insert("", cx);

                // Fixup cursor position after the deletion
                editor.set_clip_at_line_ends(true, cx);
                editor.change_selections(Some(Autoscroll::fit()), cx, |s| {
                    s.move_with(|map, selection| {
                        let mut cursor = selection.head();
                        if motion.linewise() {
                            if let Some(column) = original_columns.get(&selection.id) {
                                *cursor.column_mut() = *column
                            }
                        }
                        cursor = map.clip_point(cursor, Bias::Left);
                        selection.collapse_to(cursor, selection.goal)
                    });
                });
                editor.refresh_inline_completion(true, false, cx);
            });
        });
    }

    pub fn delete_object(&mut self, object: Object, around: bool, cx: &mut ViewContext<Self>) {
        self.stop_recording(cx);
        self.update_editor(cx, |vim, editor, cx| {
            editor.transact(cx, |editor, cx| {
                editor.set_clip_at_line_ends(false, cx);
                // Emulates behavior in vim where if we expanded backwards to include a newline
                // the cursor gets set back to the start of the line
                let mut should_move_to_start: HashSet<_> = Default::default();
                editor.change_selections(Some(Autoscroll::fit()), cx, |s| {
                    s.move_with(|map, selection| {
                        object.expand_selection(map, selection, around);
                        let offset_range = selection.map(|p| p.to_offset(map, Bias::Left)).range();
                        let mut move_selection_start_to_previous_line =
                            |map: &DisplaySnapshot, selection: &mut Selection<DisplayPoint>| {
                                let start = selection.start.to_offset(map, Bias::Left);
                                if selection.start.row().0 > 0 {
                                    should_move_to_start.insert(selection.id);
                                    selection.start =
                                        (start - '\n'.len_utf8()).to_display_point(map);
                                }
                            };
                        let range = selection.start.to_offset(map, Bias::Left)
                            ..selection.end.to_offset(map, Bias::Right);
                        let contains_only_newlines = map
                            .buffer_chars_at(range.start)
                            .take_while(|(_, p)| p < &range.end)
                            .all(|(char, _)| char == '\n')
                            && !offset_range.is_empty();
                        let end_at_newline = map
                            .buffer_chars_at(range.end)
                            .next()
                            .map(|(c, _)| c == '\n')
                            .unwrap_or(false);

                        // If expanded range contains only newlines and
                        // the object is around or sentence, expand to include a newline
                        // at the end or start
                        if (around || object == Object::Sentence) && contains_only_newlines {
                            if end_at_newline {
                                move_selection_end_to_next_line(map, selection);
                            } else {
                                move_selection_start_to_previous_line(map, selection);
                            }
                        }

                        // Does post-processing for the trailing newline and EOF
                        // when not cancelled.
                        let cancelled = around && selection.start == selection.end;
                        if object == Object::Paragraph && !cancelled {
                            // EOF check should be done before including a trailing newline.
                            if ends_at_eof(map, selection) {
                                move_selection_start_to_previous_line(map, selection);
                            }

                            if end_at_newline {
                                move_selection_end_to_next_line(map, selection);
                            }
                        }
                    });
                });
                vim.copy_selections_content(editor, false, cx);
                editor.insert("", cx);

                // Fixup cursor position after the deletion
                editor.set_clip_at_line_ends(true, cx);
                editor.change_selections(Some(Autoscroll::fit()), cx, |s| {
                    s.move_with(|map, selection| {
                        let mut cursor = selection.head();
                        if should_move_to_start.contains(&selection.id) {
                            *cursor.column_mut() = 0;
                        }
                        cursor = map.clip_point(cursor, Bias::Left);
                        selection.collapse_to(cursor, selection.goal)
                    });
                });
                editor.refresh_inline_completion(true, false, cx);
            });
        });
    }
}

fn move_selection_end_to_next_line(map: &DisplaySnapshot, selection: &mut Selection<DisplayPoint>) {
    let end = selection.end.to_offset(map, Bias::Left);
    selection.end = (end + '\n'.len_utf8()).to_display_point(map);
}

fn ends_at_eof(map: &DisplaySnapshot, selection: &mut Selection<DisplayPoint>) -> bool {
    selection.end.to_point(map) == map.buffer_snapshot.max_point()
}

#[cfg(test)]
mod test {
    use indoc::indoc;

    use crate::{
        state::Mode,
        test::{NeovimBackedTestContext, VimTestContext},
    };

    #[gpui::test]
    async fn test_delete_h(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate("d h", "TeËst").await.assert_matches();
        cx.simulate("d h", "TËest").await.assert_matches();
        cx.simulate("d h", "ËTest").await.assert_matches();
        cx.simulate(
            "d h",
            indoc! {"
            Test
            Ëtest"},
        )
        .await
        .assert_matches();
    }

    #[gpui::test]
    async fn test_delete_l(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate("d l", "ËTest").await.assert_matches();
        cx.simulate("d l", "TeËst").await.assert_matches();
        cx.simulate("d l", "TesËt").await.assert_matches();
        cx.simulate(
            "d l",
            indoc! {"
                TesËt
                test"},
        )
        .await
        .assert_matches();
    }

    #[gpui::test]
    async fn test_delete_w(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate(
            "d w",
            indoc! {"
            Test tesËt
                test"},
        )
        .await
        .assert_matches();

        cx.simulate("d w", "TeËst").await.assert_matches();
        cx.simulate("d w", "TËest test").await.assert_matches();
        cx.simulate(
            "d w",
            indoc! {"
            Test teËst
            test"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "d w",
            indoc! {"
            Test tesËt
            test"},
        )
        .await
        .assert_matches();

        cx.simulate(
            "d w",
            indoc! {"
            Test test
            Ë
            test"},
        )
        .await
        .assert_matches();

        cx.simulate("d shift-w", "Test teËst-test test")
            .await
            .assert_matches();
    }

    #[gpui::test]
    async fn test_delete_next_word_end(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate("d e", "TeËst Test\n").await.assert_matches();
        cx.simulate("d e", "TËest test\n").await.assert_matches();
        cx.simulate(
            "d e",
            indoc! {"
            Test teËst
            test"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "d e",
            indoc! {"
            Test tesËt
            test"},
        )
        .await
        .assert_matches();

        cx.simulate("d e", "Test teËst-test test")
            .await
            .assert_matches();
    }

    #[gpui::test]
    async fn test_delete_b(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate("d b", "TeËst Test").await.assert_matches();
        cx.simulate("d b", "Test Ëtest").await.assert_matches();
        cx.simulate("d b", "Test1 test2 Ëtest3")
            .await
            .assert_matches();
        cx.simulate(
            "d b",
            indoc! {"
            Test test
            Ëtest"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "d b",
            indoc! {"
            Test test
            Ë
            test"},
        )
        .await
        .assert_matches();

        cx.simulate("d shift-b", "Test test-test Ëtest")
            .await
            .assert_matches();
    }

    #[gpui::test]
    async fn test_delete_end_of_line(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate(
            "d $",
            indoc! {"
            The qËuick
            brown fox"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "d $",
            indoc! {"
            The quick
            Ë
            brown fox"},
        )
        .await
        .assert_matches();
    }

    #[gpui::test]
    async fn test_delete_0(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate(
            "d 0",
            indoc! {"
            The qËuick
            brown fox"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "d 0",
            indoc! {"
            The quick
            Ë
            brown fox"},
        )
        .await
        .assert_matches();
    }

    #[gpui::test]
    async fn test_delete_k(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate(
            "d k",
            indoc! {"
            The quick
            brown Ëfox
            jumps over"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "d k",
            indoc! {"
            The quick
            brown fox
            jumps Ëover"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "d k",
            indoc! {"
            The qËuick
            brown fox
            jumps over"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "d k",
            indoc! {"
            Ëbrown fox
            jumps over"},
        )
        .await
        .assert_matches();
    }

    #[gpui::test]
    async fn test_delete_j(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate(
            "d j",
            indoc! {"
            The quick
            brown Ëfox
            jumps over"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "d j",
            indoc! {"
            The quick
            brown fox
            jumps Ëover"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "d j",
            indoc! {"
            The qËuick
            brown fox
            jumps over"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "d j",
            indoc! {"
            The quick
            brown fox
            Ë"},
        )
        .await
        .assert_matches();
    }

    #[gpui::test]
    async fn test_delete_end_of_document(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate(
            "d shift-g",
            indoc! {"
            The quick
            brownË fox
            jumps over
            the lazy"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "d shift-g",
            indoc! {"
            The quick
            brownË fox
            jumps over
            the lazy"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "d shift-g",
            indoc! {"
            The quick
            brown fox
            jumps over
            the lËazy"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "d shift-g",
            indoc! {"
            The quick
            brown fox
            jumps over
            Ë"},
        )
        .await
        .assert_matches();
    }

    #[gpui::test]
    async fn test_delete_gg(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate(
            "d g g",
            indoc! {"
            The quick
            brownË fox
            jumps over
            the lazy"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "d g g",
            indoc! {"
            The quick
            brown fox
            jumps over
            the lËazy"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "d g g",
            indoc! {"
            The qËuick
            brown fox
            jumps over
            the lazy"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "d g g",
            indoc! {"
            Ë
            brown fox
            jumps over
            the lazy"},
        )
        .await
        .assert_matches();
    }

    #[gpui::test]
    async fn test_cancel_delete_operator(cx: &mut gpui::TestAppContext) {
        let mut cx = VimTestContext::new(cx, true).await;
        cx.set_state(
            indoc! {"
                The quick brown
                fox juËmps over
                the lazy dog"},
            Mode::Normal,
        );

        // Canceling operator twice reverts to normal mode with no active operator
        cx.simulate_keystrokes("d escape k");
        assert_eq!(cx.active_operator(), None);
        assert_eq!(cx.mode(), Mode::Normal);
        cx.assert_editor_state(indoc! {"
            The quËick brown
            fox jumps over
            the lazy dog"});
    }

    #[gpui::test]
    async fn test_unbound_command_cancels_pending_operator(cx: &mut gpui::TestAppContext) {
        let mut cx = VimTestContext::new(cx, true).await;
        cx.set_state(
            indoc! {"
                The quick brown
                fox juËmps over
                the lazy dog"},
            Mode::Normal,
        );

        // Canceling operator twice reverts to normal mode with no active operator
        cx.simulate_keystrokes("d y");
        assert_eq!(cx.active_operator(), None);
        assert_eq!(cx.mode(), Mode::Normal);
    }

    #[gpui::test]
    async fn test_delete_with_counts(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.set_shared_state(indoc! {"
                The Ëquick brown
                fox jumps over
                the lazy dog"})
            .await;
        cx.simulate_shared_keystrokes("d 2 d").await;
        cx.shared_state().await.assert_eq(indoc! {"
        the Ëlazy dog"});

        cx.set_shared_state(indoc! {"
                The Ëquick brown
                fox jumps over
                the lazy dog"})
            .await;
        cx.simulate_shared_keystrokes("2 d d").await;
        cx.shared_state().await.assert_eq(indoc! {"
        the Ëlazy dog"});

        cx.set_shared_state(indoc! {"
                The Ëquick brown
                fox jumps over
                the moon,
                a star, and
                the lazy dog"})
            .await;
        cx.simulate_shared_keystrokes("2 d 2 d").await;
        cx.shared_state().await.assert_eq(indoc! {"
        the Ëlazy dog"});
    }

    #[gpui::test]
    async fn test_delete_to_adjacent_character(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate("d t x", "Ëax").await.assert_matches();
        cx.simulate("d t x", "aËx").await.assert_matches();
    }

    #[gpui::test]
    async fn test_delete_sentence(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate(
            "d )",
            indoc! {"
            FiËrst. Second. Third.
            Fourth.
            "},
        )
        .await
        .assert_matches();

        cx.simulate(
            "d )",
            indoc! {"
            First. SecËond. Third.
            Fourth.
            "},
        )
        .await
        .assert_matches();

        // Two deletes
        cx.simulate(
            "d ) d )",
            indoc! {"
            First. Second. ThirËd.
            Fourth.
            "},
        )
        .await
        .assert_matches();

        // Should delete whole line if done on first column
        cx.simulate(
            "d )",
            indoc! {"
            ËFirst.
            Fourth.
            "},
        )
        .await
        .assert_matches();

        // Backwards it should also delete the whole first line
        cx.simulate(
            "d (",
            indoc! {"
            First.
            ËSecond.
            Fourth.
            "},
        )
        .await
        .assert_matches();
    }
}
