use crate::{
    motion::{self, Motion},
    object::Object,
    state::Mode,
    Vim,
};
use editor::{
    display_map::{DisplaySnapshot, ToDisplayPoint},
    movement::TextLayoutDetails,
    scroll::Autoscroll,
    Bias, DisplayPoint,
};
use language::Selection;
use ui::ViewContext;

impl Vim {
    pub fn change_motion(
        &mut self,
        motion: Motion,
        times: Option<usize>,
        cx: &mut ViewContext<Self>,
    ) {
        // Some motions ignore failure when switching to normal mode
        let mut motion_succeeded = matches!(
            motion,
            Motion::Left
                | Motion::Right
                | Motion::EndOfLine { .. }
                | Motion::Backspace
                | Motion::StartOfLine { .. }
        );
        self.update_editor(cx, |vim, editor, cx| {
            let text_layout_details = editor.text_layout_details(cx);
            editor.transact(cx, |editor, cx| {
                // We are swapping to insert mode anyway. Just set the line end clipping behavior now
                editor.set_clip_at_line_ends(false, cx);
                editor.change_selections(Some(Autoscroll::fit()), cx, |s| {
                    s.move_with(|map, selection| {
                        motion_succeeded |= match motion {
                            Motion::NextWordStart { ignore_punctuation }
                            | Motion::NextSubwordStart { ignore_punctuation } => {
                                expand_changed_word_selection(
                                    map,
                                    selection,
                                    times,
                                    ignore_punctuation,
                                    &text_layout_details,
                                    motion == Motion::NextSubwordStart { ignore_punctuation },
                                )
                            }
                            _ => {
                                let result = motion.expand_selection(
                                    map,
                                    selection,
                                    times,
                                    false,
                                    &text_layout_details,
                                );
                                if let Motion::CurrentLine = motion {
                                    let mut start_offset =
                                        selection.start.to_offset(map, Bias::Left);
                                    let classifier = map
                                        .buffer_snapshot
                                        .char_classifier_at(selection.start.to_point(map));
                                    for (ch, offset) in map.buffer_chars_at(start_offset) {
                                        if ch == '\n' || !classifier.is_whitespace(ch) {
                                            break;
                                        }
                                        start_offset = offset + ch.len_utf8();
                                    }
                                    selection.start = start_offset.to_display_point(map);
                                }
                                result
                            }
                        }
                    });
                });
                vim.copy_selections_content(editor, motion.linewise(), cx);
                editor.insert("", cx);
                editor.refresh_inline_completion(true, false, cx);
            });
        });

        if motion_succeeded {
            self.switch_mode(Mode::Insert, false, cx)
        } else {
            self.switch_mode(Mode::Normal, false, cx)
        }
    }

    pub fn change_object(&mut self, object: Object, around: bool, cx: &mut ViewContext<Self>) {
        let mut objects_found = false;
        self.update_editor(cx, |vim, editor, cx| {
            // We are swapping to insert mode anyway. Just set the line end clipping behavior now
            editor.set_clip_at_line_ends(false, cx);
            editor.transact(cx, |editor, cx| {
                editor.change_selections(Some(Autoscroll::fit()), cx, |s| {
                    s.move_with(|map, selection| {
                        objects_found |= object.expand_selection(map, selection, around);
                    });
                });
                if objects_found {
                    vim.copy_selections_content(editor, false, cx);
                    editor.insert("", cx);
                    editor.refresh_inline_completion(true, false, cx);
                }
            });
        });

        if objects_found {
            self.switch_mode(Mode::Insert, false, cx);
        } else {
            self.switch_mode(Mode::Normal, false, cx);
        }
    }
}

// From the docs https://vimdoc.sourceforge.net/htmldoc/motion.html
// Special case: "cw" and "cW" are treated like "ce" and "cE" if the cursor is
// on a non-blank.  This is because "cw" is interpreted as change-word, and a
// word does not include the following white space.  {Vi: "cw" when on a blank
// followed by other blanks changes only the first blank; this is probably a
// bug, because "dw" deletes all the blanks}
fn expand_changed_word_selection(
    map: &DisplaySnapshot,
    selection: &mut Selection<DisplayPoint>,
    times: Option<usize>,
    ignore_punctuation: bool,
    text_layout_details: &TextLayoutDetails,
    use_subword: bool,
) -> bool {
    let is_in_word = || {
        let classifier = map
            .buffer_snapshot
            .char_classifier_at(selection.start.to_point(map));
        let in_word = map
            .buffer_chars_at(selection.head().to_offset(map, Bias::Left))
            .next()
            .map(|(c, _)| !classifier.is_whitespace(c))
            .unwrap_or_default();
        in_word
    };
    if (times.is_none() || times.unwrap() == 1) && is_in_word() {
        let next_char = map
            .buffer_chars_at(
                motion::next_char(map, selection.end, false).to_offset(map, Bias::Left),
            )
            .next();
        match next_char {
            Some((' ', _)) => selection.end = motion::next_char(map, selection.end, false),
            _ => {
                if use_subword {
                    selection.end =
                        motion::next_subword_end(map, selection.end, ignore_punctuation, 1, false);
                } else {
                    selection.end =
                        motion::next_word_end(map, selection.end, ignore_punctuation, 1, false);
                }
                selection.end = motion::next_char(map, selection.end, false);
            }
        }
        true
    } else {
        let motion = if use_subword {
            Motion::NextSubwordStart { ignore_punctuation }
        } else {
            Motion::NextWordStart { ignore_punctuation }
        };
        motion.expand_selection(map, selection, times, false, text_layout_details)
    }
}

#[cfg(test)]
mod test {
    use indoc::indoc;

    use crate::test::NeovimBackedTestContext;

    #[gpui::test]
    async fn test_change_h(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate("c h", "TeËst").await.assert_matches();
        cx.simulate("c h", "TËest").await.assert_matches();
        cx.simulate("c h", "ËTest").await.assert_matches();
        cx.simulate(
            "c h",
            indoc! {"
            Test
            Ëtest"},
        )
        .await
        .assert_matches();
    }

    #[gpui::test]
    async fn test_change_backspace(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate("c backspace", "TeËst").await.assert_matches();
        cx.simulate("c backspace", "TËest").await.assert_matches();
        cx.simulate("c backspace", "ËTest").await.assert_matches();
        cx.simulate(
            "c backspace",
            indoc! {"
            Test
            Ëtest"},
        )
        .await
        .assert_matches();
    }

    #[gpui::test]
    async fn test_change_l(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate("c l", "TeËst").await.assert_matches();
        cx.simulate("c l", "TesËt").await.assert_matches();
    }

    #[gpui::test]
    async fn test_change_w(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate("c w", "TeËst").await.assert_matches();
        cx.simulate("c w", "TËest test").await.assert_matches();
        cx.simulate("c w", "TestË  test").await.assert_matches();
        cx.simulate("c w", "TesËt  test").await.assert_matches();
        cx.simulate(
            "c w",
            indoc! {"
                Test teËst
                test"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "c w",
            indoc! {"
                Test tesËt
                test"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "c w",
            indoc! {"
                Test test
                Ë
                test"},
        )
        .await
        .assert_matches();

        cx.simulate("c shift-w", "Test teËst-test test")
            .await
            .assert_matches();
    }

    #[gpui::test]
    async fn test_change_e(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate("c e", "TeËst Test").await.assert_matches();
        cx.simulate("c e", "TËest test").await.assert_matches();
        cx.simulate(
            "c e",
            indoc! {"
                Test teËst
                test"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "c e",
            indoc! {"
                Test tesËt
                test"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "c e",
            indoc! {"
                Test test
                Ë
                test"},
        )
        .await
        .assert_matches();

        cx.simulate("c shift-e", "Test teËst-test test")
            .await
            .assert_matches();
    }

    #[gpui::test]
    async fn test_change_b(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate("c b", "TeËst Test").await.assert_matches();
        cx.simulate("c b", "Test Ëtest").await.assert_matches();
        cx.simulate("c b", "Test1 test2 Ëtest3")
            .await
            .assert_matches();
        cx.simulate(
            "c b",
            indoc! {"
                Test test
                Ëtest"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "c b",
            indoc! {"
                Test test
                Ë
                test"},
        )
        .await
        .assert_matches();

        cx.simulate("c shift-b", "Test test-test Ëtest")
            .await
            .assert_matches();
    }

    #[gpui::test]
    async fn test_change_end_of_line(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate(
            "c $",
            indoc! {"
            The qËuick
            brown fox"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "c $",
            indoc! {"
            The quick
            Ë
            brown fox"},
        )
        .await
        .assert_matches();
    }

    #[gpui::test]
    async fn test_change_0(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;

        cx.simulate(
            "c 0",
            indoc! {"
            The qËuick
            brown fox"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "c 0",
            indoc! {"
            The quick
            Ë
            brown fox"},
        )
        .await
        .assert_matches();
    }

    #[gpui::test]
    async fn test_change_k(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;

        cx.simulate(
            "c k",
            indoc! {"
            The quick
            brown Ëfox
            jumps over"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "c k",
            indoc! {"
            The quick
            brown fox
            jumps Ëover"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "c k",
            indoc! {"
            The qËuick
            brown fox
            jumps over"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "c k",
            indoc! {"
            Ë
            brown fox
            jumps over"},
        )
        .await
        .assert_matches();
    }

    #[gpui::test]
    async fn test_change_j(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate(
            "c j",
            indoc! {"
            The quick
            brown Ëfox
            jumps over"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "c j",
            indoc! {"
            The quick
            brown fox
            jumps Ëover"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "c j",
            indoc! {"
            The qËuick
            brown fox
            jumps over"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "c j",
            indoc! {"
            The quick
            brown fox
            Ë"},
        )
        .await
        .assert_matches();
    }

    #[gpui::test]
    async fn test_change_end_of_document(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate(
            "c shift-g",
            indoc! {"
            The quick
            brownË fox
            jumps over
            the lazy"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "c shift-g",
            indoc! {"
            The quick
            brownË fox
            jumps over
            the lazy"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "c shift-g",
            indoc! {"
            The quick
            brown fox
            jumps over
            the lËazy"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "c shift-g",
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
    async fn test_change_cc(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate(
            "c c",
            indoc! {"
           The quick
             brownË fox
           jumps over
           the lazy"},
        )
        .await
        .assert_matches();

        cx.simulate(
            "c c",
            indoc! {"
           ËThe quick
           brown fox
           jumps over
           the lazy"},
        )
        .await
        .assert_matches();

        cx.simulate(
            "c c",
            indoc! {"
           The quick
             broËwn fox
           jumps over
           the lazy"},
        )
        .await
        .assert_matches();
    }

    #[gpui::test]
    async fn test_change_gg(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate(
            "c g g",
            indoc! {"
            The quick
            brownË fox
            jumps over
            the lazy"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "c g g",
            indoc! {"
            The quick
            brown fox
            jumps over
            the lËazy"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "c g g",
            indoc! {"
            The qËuick
            brown fox
            jumps over
            the lazy"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "c g g",
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
    async fn test_repeated_cj(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;

        for count in 1..=5 {
            cx.simulate_at_each_offset(
                &format!("c {count} j"),
                indoc! {"
                    ËThe quËickË browËn
                    Ë
                    Ëfox ËjumpsË-ËoËver
                    Ëthe lazy dog
                    "},
            )
            .await
            .assert_matches();
        }
    }

    #[gpui::test]
    async fn test_repeated_cl(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;

        for count in 1..=5 {
            cx.simulate_at_each_offset(
                &format!("c {count} l"),
                indoc! {"
                    ËThe quËickË browËn
                    Ë
                    Ëfox ËjumpsË-ËoËver
                    Ëthe lazy dog
                    "},
            )
            .await
            .assert_matches();
        }
    }

    #[gpui::test]
    async fn test_repeated_cb(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;

        for count in 1..=5 {
            cx.simulate_at_each_offset(
                &format!("c {count} b"),
                indoc! {"
                ËThe quËickË browËn
                Ë
                Ëfox ËjumpsË-ËoËver
                Ëthe lazy dog
                "},
            )
            .await
            .assert_matches()
        }
    }

    #[gpui::test]
    async fn test_repeated_ce(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;

        for count in 1..=5 {
            cx.simulate_at_each_offset(
                &format!("c {count} e"),
                indoc! {"
                    ËThe quËickË browËn
                    Ë
                    Ëfox ËjumpsË-ËoËver
                    Ëthe lazy dog
                    "},
            )
            .await
            .assert_matches();
        }
    }
}
