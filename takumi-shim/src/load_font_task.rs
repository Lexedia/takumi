use takumi::GlobalContext;
use takumi::parley::{FontWeight, fontique::FontInfoOverride};

#[derive(Clone, Debug)]
pub struct FontMetadata {
    pub name: Option<String>,
    pub weight: Option<f64>,
    pub style: Option<u8>, // 0=normal, 1=italic, 2=oblique
}

pub struct LoadFontTask<'a> {
    pub context: &'a mut GlobalContext,
    pub buffers: Vec<(FontMetadata, Vec<u8>)>,
}

impl<'a> LoadFontTask<'a> {
    pub fn new(context: &'a mut GlobalContext) -> Self {
        LoadFontTask {
            context,
            buffers: Vec::new(),
        }
    }

    pub fn add_font(&mut self, metadata: FontMetadata, data: Vec<u8>) {
        self.buffers.push((metadata, data));
    }

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
                width: None,
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
