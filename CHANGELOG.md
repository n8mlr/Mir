# Mir Changelog

### 0.1.4

* Fixed bug that occurred during pull operations when the connection with Amazon S3 is interrupted mid-transmission. Pull operations will now continue to download an asset from S3 until the checksum matches what has been stored in the local index
* Added configuration option max_download_attempts to allow the user to set the maximum number of pull attempts per file