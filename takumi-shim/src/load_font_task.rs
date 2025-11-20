use takumi::GlobalContext;
use takumi::parley::FontWidth;
use takumi::parley::{FontWeight, fontique::FontInfoOverride};

#[derive(Clone, Debug)]
pub struct FontMetadata {
    /// Optional font family name.
    pub name: Option<String>,

    /// Optional font weight (e.g., 400.0 for normal, 700.0 for bold).
    pub weight: Option<f64>,

    /// Optional font style.
    /// - `0` = normal
    /// - `1` = italic
    /// - `2` = oblique
    pub style: Option<u8>,

    /// Optional font width (e.g., 1.0 for normal, <1.0 for condensed, >1.0 for expanded).
    pub width: Option<f64>,
}

/// Task to load fonts into the global context from provided byte buffers.
pub struct LoadFontTask<'a> {
    /// Mutable reference to the global context.
    pub context: &'a mut GlobalContext,

    /// List of pairs to load.
    pub buffers: Vec<(FontMetadata, Vec<u8>)>,
}

impl<'a> LoadFontTask<'a> {
    /// Creates a new LoadFontTask with the given global context.
    pub fn new(context: &'a mut GlobalContext) -> Self {
        LoadFontTask {
            context,
            buffers: Vec::new(),
        }
    }

    /// Adds a font to be loaded with the given metadata and byte buffer.
    pub fn add_font(&mut self, metadata: FontMetadata, data: Vec<u8>) {
        self.buffers.push((metadata, data));
    }

    /// Loads the fonts into the global context.
    pub fn compute(&mut self) -> Result<usize, String> {
        if self.buffers.is_empty() {
            return Ok(0);
        }

        let mut loaded_count = 0;

        for (font, buffer) in &self.buffers {
            let font_style = match font.style {
                Some(0) => Some(takumi::parley::FontStyle::Normal),
                Some(1) => Some(takumi::parley::FontStyle::Italic),
                Some(2) => Some(takumi::parley::FontStyle::Oblique(None)),
                _ => Some(takumi::parley::FontStyle::Normal),
            };

            let font_override = FontInfoOverride {
                family_name: font.name.as_deref(),
                width: font.width.map(|width| FontWidth::from_ratio(width as f32)),
                style: font_style,
                weight: font.weight.map(|weight| FontWeight::new(weight as f32)),
                axes: None,
            };

            if self
                .context
                .font_context
                .load_and_store(buffer, Some(font_override), None)
                .is_ok()
            {
                loaded_count += 1;
            }
        }

        Ok(loaded_count)
    }
}
