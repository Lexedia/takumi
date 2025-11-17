use takumi::resources::image::{PersistentImageStore, load_image_source_from_bytes};

pub struct PutPersistentImageTask<'s> {
    pub src: Option<String>,
    pub store: &'s PersistentImageStore,
    pub data: Vec<u8>,
}

impl<'s> PutPersistentImageTask<'s> {
    pub fn new(src: String, store: &'s PersistentImageStore, data: Vec<u8>) -> Self {
        PutPersistentImageTask {
            src: Some(src),
            store,
            data,
        }
    }

    pub fn compute(&mut self) -> Result<(), String> {
        let image = load_image_source_from_bytes(&self.data)
            .map_err(|e| format!("Failed to load image: {:?}", e))?;
        
        let src = self.src.take().ok_or_else(|| "src not set".to_string())?;
        self.store.insert(src, image);
        
        Ok(())
    }
}
