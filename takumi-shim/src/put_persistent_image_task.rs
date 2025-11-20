use takumi::resources::image::{PersistentImageStore, load_image_source_from_bytes};

/// Task to put a persistent image into the store.
pub struct PutPersistentImageTask<'s> {
    /// Optional source key for the image.
    pub src: Option<String>,

    /// Reference to the persistent image store.
    pub store: &'s PersistentImageStore,

    /// Byte data of the image.
    pub data: Vec<u8>,
}

impl<'s> PutPersistentImageTask<'s> {
    /// Creates a new PutPersistentImageTask with the given source, store, and data.
    pub fn new(src: String, store: &'s PersistentImageStore, data: Vec<u8>) -> Self {
        PutPersistentImageTask {
            src: Some(src),
            store,
            data,
        }
    }

    /// Puts the persistent image into the store.
    pub fn compute(&mut self) -> Result<(), String> {
        let image = load_image_source_from_bytes(&self.data)
            .map_err(|e| format!("Failed to load image: {:?}", e))?;
        
        let src = self.src.take().ok_or_else(|| "src not set".to_string())?;
        self.store.insert(src, image);
        
        Ok(())
    }
}
