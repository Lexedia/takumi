use rayon::iter::{IntoParallelIterator, ParallelIterator};
use std::io::Cursor;
use takumi::{
    GlobalContext,
    layout::{Viewport, node::NodeKind},
    rendering::{
        AnimationFrame, RenderOptionsBuilder, encode_animated_png, encode_animated_webp, render,
    },
};

use crate::renderer::AnimationOutputFormat;

pub struct RenderAnimationTask<'g> {
    pub nodes: Option<Vec<(NodeKind, u32)>>,
    pub context: &'g GlobalContext,
    pub viewport: Viewport,
    pub format: AnimationOutputFormat,
    pub draw_debug_border: bool,
}

impl RenderAnimationTask<'_> {
    pub fn new(
        nodes: Vec<(NodeKind, u32)>,
        context: &'_ GlobalContext,
        viewport: Viewport,
        format: AnimationOutputFormat,
        draw_debug_border: bool,
    ) -> RenderAnimationTask<'_> {
        RenderAnimationTask {
            nodes: Some(nodes),
            context,
            viewport,
            format,
            draw_debug_border,
        }
    }

    pub fn compute(&mut self) -> Result<Vec<u8>, takumi::Error> {
        let nodes = self.nodes.take().unwrap();

        let frames: Vec<_> = nodes
            .into_par_iter()
            .map(|(node, duration_ms)| {
                AnimationFrame::new(
                    render(
                        RenderOptionsBuilder::default()
                            .viewport(self.viewport)
                            .node(node)
                            .global(self.context)
                            .draw_debug_border(self.draw_debug_border)
                            .build()
                            .unwrap(),
                    )
                    .unwrap(),
                    duration_ms,
                )
            })
            .collect();

        let mut buffer = Vec::new();
        let mut cursor = Cursor::new(&mut buffer);

        match self.format {
            AnimationOutputFormat::Webp => {
                encode_animated_webp(&frames, &mut cursor, true, false, None)?
            }
            AnimationOutputFormat::Apng => {
                encode_animated_png(&frames, &mut cursor, None)?
            }
        }

        Ok(buffer)
    }
}
