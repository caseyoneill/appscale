package com.google.appengine.api.blobstore.dev;


import java.io.File;

public class BlobStorageFactory
{
    private static final BlobInfoStorage blobInfoStorage = new BlobInfoStorage();
    private static BlobStorage           blobStorage;

    public static BlobInfoStorage getBlobInfoStorage()
    {
        return blobInfoStorage;
    }

    public static BlobStorage getBlobStorage()
    {
		if (blobStorage == null)
        {
			//default to datastore backed blobstorage
			setDatastoreBlobStorage();

        	if (blobStorage == null)
        	{
            	throw new IllegalStateException("Must call one of set*BlobStorage() first.");
        	}
		}
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
    }
}
