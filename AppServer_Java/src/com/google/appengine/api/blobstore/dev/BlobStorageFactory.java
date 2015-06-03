package com.google.appengine.api.blobstore.dev;


import java.io.File;
import java.util.logging.Level;
import java.util.logging.Logger;

import com.google.appengine.api.blobstore.dev.BlobInfoStorage;
import com.google.appengine.api.blobstore.dev.BlobStorage;

public class BlobStorageFactory
{
    private static final Logger		 logger = Logger.getLogger(BlobStorageFactory.class.getName());
    private static final BlobInfoStorage blobInfoStorage = new BlobInfoStorage();
    private static BlobStorage           blobStorage;

    public static BlobInfoStorage getBlobInfoStorage()
    {
        return blobInfoStorage;
    }

    public static BlobStorage getBlobStorage()
    {
	//logger.fine("Retrieving BlobStorage..");
        if (blobStorage == null)
        {
            logger.severe("BlobStorage is null.");
            throw new IllegalStateException("Must call one of set*BlobStorage() first.");
        }
	//logger.fine("BlobStorage retrieved.");
        return blobStorage;
    }

    static void setFileBlobStorage( File blobRoot )
    {
        blobStorage = new FileBlobStorage(blobRoot, blobInfoStorage);
    }

    static void setMemoryBlobStorage()
    {
        blobStorage = new MemoryBlobStorage(blobInfoStorage);
    }

    public static void setDatastoreBlobStorage()
    {
        blobStorage = new DatastoreBlobStorage(blobInfoStorage);
        //logger.fine("BlobStorage created.");
    }
}
