use crate::renderer::OutputFormat;
use std::collections::HashMap;
use std::io::Cursor;
use std::sync::Arc;
use takumi::{
    Error, GlobalContext,
    layout::{Viewport, node::NodeKind},
    rendering::{RenderOptionsBuilder, render, write_image},
    resources::image::ImageSource,
};

pub fn parse_node_from_json(json_bytes: &[u8]) -> Result<NodeKind, serde_json::Error> {
    serde_json::from_slice(json_bytes)
}

/// A task to render a node to an image.
pub struct RenderTask<'g> {
    /// The node to render.
    pub node: Option<NodeKind>,

    /// The global context.
    pub global: &'g GlobalContext,

    /// The viewport to use for rendering.
    pub viewport: Viewport,

    /// The output format.
    pub format: OutputFormat,

    /// The quality for lossy formats (0-100).
    pub quality: Option<u8>,

    /// Whether to draw a debug border around the rendered content.
    pub draw_debug_border: bool,

    /// Fetched resources to be used during rendering.
    pub fetched_resources: HashMap<Arc<str>, Arc<ImageSource>>,
}

impl RenderTask<'_> {
    /// Creates a new RenderTask.
    pub fn new(
        node: NodeKind,
        global: &GlobalContext,
        viewport: Viewport,
        format: OutputFormat,
        quality: Option<u8>,
        draw_debug_border: bool,
    ) -> RenderTask<'_> {
        RenderTask {
            node: Some(node),
            global,
            viewport,
            format,
            quality,
            draw_debug_border,
            fetched_resources: HashMap::new(),
        }
    }

    /// Adds a fetched resource to be used during rendering.
    pub fn add_fetched_resource(&mut self, url: String, source: ImageSource) {
        self.fetched_resources
            .insert(Arc::from(url.as_str()), Arc::new(source));
    }

    /// Computes the rendering task and returns the rendered image as a byte vector.
    pub fn compute(&mut self) -> Result<Vec<u8>, String> {
        let node = self.node.take().ok_or_else(|| "node not set".to_string())?;

        let image = render(
            RenderOptionsBuilder::default()
                .viewport(self.viewport)
                .fetched_resources(self.fetched_resources.clone())
                .node(node)
                .global(&self.global)
                .draw_debug_border(self.draw_debug_border)
                .build()
                .map_err(|e| format!("Failed to build render options: {:?}", e))?,
        )
        .map_err(|e| match e {
            Error::InvalidViewport => format!(
                "Invalid viewport specified, given {:?}x{:?}",
                self.viewport.width, self.viewport.height
            ),
            other => format!("Rendering failed: {:?}", other),
        })?;

        if self.format == OutputFormat::Raw {
            return Ok(image.into_raw());
        }

        let mut buffer = Vec::new();
        let mut cursor = Cursor::new(&mut buffer);

        write_image(&image, &mut cursor, self.format.into(), self.quality)
            .map_err(|e| format!("Failed to write to buffer: {:?}", e))?;

        Ok(buffer)
    }
}
