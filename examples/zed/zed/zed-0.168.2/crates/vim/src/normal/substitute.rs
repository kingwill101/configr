use editor::{movement, Editor};
use gpui::{actions, ViewContext};
use language::Point;

use crate::{motion::Motion, Mode, Vim};

actions!(vim, [Substitute, SubstituteLine]);

pub(crate) fn register(editor: &mut Editor, cx: &mut ViewContext<Vim>) {
    Vim::action(editor, cx, |vim, _: &Substitute, cx| {
        vim.start_recording(cx);
        let count = Vim::take_count(cx);
        vim.substitute(count, vim.mode == Mode::VisualLine, cx);
    });

    Vim::action(editor, cx, |vim, _: &SubstituteLine, cx| {
        vim.start_recording(cx);
        if matches!(vim.mode, Mode::VisualBlock | Mode::Visual) {
            vim.switch_mode(Mode::VisualLine, false, cx)
        }
        let count = Vim::take_count(cx);
        vim.substitute(count, true, cx)
    });
}

impl Vim {
    pub fn substitute(
        &mut self,
        count: Option<usize>,
        line_mode: bool,
        cx: &mut ViewContext<Self>,
    ) {
        self.store_visual_marks(cx);
        self.update_editor(cx, |vim, editor, cx| {
            editor.set_clip_at_line_ends(false, cx);
            editor.transact(cx, |editor, cx| {
                let text_layout_details = editor.text_layout_details(cx);
                editor.change_selections(None, cx, |s| {
                    s.move_with(|map, selection| {
                        if selection.start == selection.end {
                            Motion::Right.expand_selection(
                                map,
                                selection,
                                count,
                                true,
                                &text_layout_details,
                            );
                        }
                        if line_mode {
                            // in Visual mode when the selection contains the newline at the end
                            // of the line, we should exclude it.
                            if !selection.is_empty() && selection.end.column() == 0 {
                                selection.end = movement::left(map, selection.end);
                            }
                            Motion::CurrentLine.expand_selection(
                                map,
                                selection,
                                None,
                                false,
                                &text_layout_details,
                            );
                            if let Some((point, _)) = (Motion::FirstNonWhitespace {
                                display_lines: false,
                            })
                            .move_point(
                                map,
                                selection.start,
                                selection.goal,
                                None,
                                &text_layout_details,
                            ) {
                                selection.start = point;
                            }
                        }
                    })
                });
                vim.copy_selections_content(editor, line_mode, cx);
                let selections = editor.selections.all::<Point>(cx).into_iter();
                let edits = selections.map(|selection| (selection.start..selection.end, ""));
                editor.edit(edits, cx);
            });
        });
        self.switch_mode(Mode::Insert, true, cx);
    }
}

#[cfg(test)]
mod test {
    use crate::{
        state::Mode,
        test::{NeovimBackedTestContext, VimTestContext},
    };
    use indoc::indoc;

    #[gpui::test]
    async fn test_substitute(cx: &mut gpui::TestAppContext) {
        let mut cx = VimTestContext::new(cx, true).await;

        // supports a single cursor
        cx.set_state(indoc! {"Ëabc\n"}, Mode::Normal);
        cx.simulate_keystrokes("s x");
        cx.assert_editor_state("xËbc\n");

        // supports a selection
        cx.set_state(indoc! {"aÂ«bcËÂ»\n"}, Mode::Visual);
        cx.assert_editor_state("aÂ«bcËÂ»\n");
        cx.simulate_keystrokes("s x");
        cx.assert_editor_state("axË\n");

        // supports counts
        cx.set_state(indoc! {"Ëabc\n"}, Mode::Normal);
        cx.simulate_keystrokes("2 s x");
        cx.assert_editor_state("xËc\n");

        // supports multiple cursors
        cx.set_state(indoc! {"aÂ«bcËÂ»deËffg\n"}, Mode::Normal);
        cx.simulate_keystrokes("2 s x");
        cx.assert_editor_state("axËdexËg\n");

        // does not read beyond end of line
        cx.set_state(indoc! {"Ëabc\n"}, Mode::Normal);
        cx.simulate_keystrokes("5 s x");
        cx.assert_editor_state("xË\n");

        // it handles multibyte characters
        cx.set_state(indoc! {"ËcÃ fÃ©\n"}, Mode::Normal);
        cx.simulate_keystrokes("4 s");
        cx.assert_editor_state("Ë\n");

        // should transactionally undo selection changes
        cx.simulate_keystrokes("escape u");
        cx.assert_editor_state("ËcÃ fÃ©\n");

        // it handles visual line mode
        cx.set_state(
            indoc! {"
            alpha
              beËta
            gamma"},
            Mode::Normal,
        );
        cx.simulate_keystrokes("shift-v s");
        cx.assert_editor_state(indoc! {"
            alpha
              Ë
            gamma"});
    }

    #[gpui::test]
    async fn test_visual_change(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;

        cx.set_shared_state("The quick Ëbrown").await;
        cx.simulate_shared_keystrokes("v w c").await;
        cx.shared_state().await.assert_eq("The quick Ë");

        cx.set_shared_state(indoc! {"
            The Ëquick brown
            fox jumps over
            the lazy dog"})
            .await;
        cx.simulate_shared_keystrokes("v w j c").await;
        cx.shared_state().await.assert_eq(indoc! {"
            The Ëver
            the lazy dog"});

        cx.simulate_at_each_offset(
            "v w j c",
            indoc! {"
                    The Ëquick brown
                    fox jumps Ëover
                    the Ëlazy dog"},
        )
        .await
        .assert_matches();
        cx.simulate_at_each_offset(
            "v w k c",
            indoc! {"
                    The Ëquick brown
                    fox jumps Ëover
                    the Ëlazy dog"},
        )
        .await
        .assert_matches();
    }

    #[gpui::test]
    async fn test_visual_line_change(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;
        cx.simulate(
            "shift-v c",
            indoc! {"
            The quËick brown
            fox jumps over
            the lazy dog"},
        )
        .await
        .assert_matches();
        // Test pasting code copied on change
        cx.simulate_shared_keystrokes("escape j p").await;
        cx.shared_state().await.assert_matches();

        cx.simulate_at_each_offset(
            "shift-v c",
            indoc! {"
            The quick brown
            fox juËmps over
            the laËzy dog"},
        )
        .await
        .assert_matches();
        cx.simulate(
            "shift-v j c",
            indoc! {"
            The quËick brown
            fox jumps over
            the lazy dog"},
        )
        .await
        .assert_matches();
        // Test pasting code copied on delete
        cx.simulate_shared_keystrokes("escape j p").await;
        cx.shared_state().await.assert_matches();

        cx.simulate_at_each_offset(
            "shift-v j c",
            indoc! {"
            The quick brown
            fox juËmps over
            the laËzy dog"},
        )
        .await
        .assert_matches();
    }

    #[gpui::test]
    async fn test_substitute_line(cx: &mut gpui::TestAppContext) {
        let mut cx = NeovimBackedTestContext::new(cx).await;

        let initial_state = indoc! {"
                    The quick brown
                    fox juËmps over
                    the lazy dog
                    "};

        // normal mode
        cx.set_shared_state(initial_state).await;
        cx.simulate_shared_keystrokes("shift-s o").await;
        cx.shared_state().await.assert_eq(indoc! {"
            The quick brown
            oË
            the lazy dog
            "});

        // visual mode
        cx.set_shared_state(initial_state).await;
        cx.simulate_shared_keystrokes("v k shift-s o").await;
        cx.shared_state().await.assert_eq(indoc! {"
            oË
            the lazy dog
            "});

        // visual block mode
        cx.set_shared_state(initial_state).await;
        cx.simulate_shared_keystrokes("ctrl-v j shift-s o").await;
        cx.shared_state().await.assert_eq(indoc! {"
            The quick brown
            oË
            "});

        // visual mode including newline
        cx.set_shared_state(initial_state).await;
        cx.simulate_shared_keystrokes("v $ shift-s o").await;
        cx.shared_state().await.assert_eq(indoc! {"
            The quick brown
            oË
            the lazy dog
            "});

        // indentation
        cx.set_neovim_option("shiftwidth=4").await;
        cx.set_shared_state(initial_state).await;
        cx.simulate_shared_keystrokes("> > shift-s o").await;
        cx.shared_state().await.assert_eq(indoc! {"
            The quick brown
                oË
            the lazy dog
            "});
    }
}
