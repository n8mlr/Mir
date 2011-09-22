# Mir

Mir is a synchronization tool to help clone a directory to a remote storage
provider. Currently only S3 is provided. A couple of the features that differentiate
Mir from other Ruby S3 synchronization tools currently available are:

* Solves S3 connection problems associated with storage and retrieval of large files (>2GB) by transparently splitting and recombining files
* Only updates and sends resources that have fallen out of synchronization
* Creates checksum comparisons on reads and writes to ensure complete end-to-end transmission
* Provides a simple command line interface for pushing and pulling files

The inspiration for this tool is to provide similar functionality to the classic Rsync command, but to utilize cloud-based storage providers.

## Configuration 

Mir uses a YAML file for configuration settings. Unless you specify otherwise, Mir will look for the file  'mir_settings.yml' in the HOME and /etc/mir directories.

    settings:
      max_upload_retries: 5
      max_threads: 5
      cloud_provider:
        type: s3
        bucket_name: gotham_backup
        access_key_id: YOUR_ACCESS_KEY
        secret_access_key: YOUR_SECRET_ACCESS_KEY
        chunk_size: 5242880
      database:
        adapter: sqlite3
        database: foobar.db

Configuration keys:

* *max_upload_retries*: This is the maximum number of attempts that Mir will try to upload your file
* *max_threads*: The maximum number of threads that will run at once
* *cloud_provider*: Currently only S3 is provided
* *chunk_size*: This is the maximum number of bytes that will be written to S3 per PUT request. This is useful for sending large files to S3 and avoiding connection errors.
* *database*: Connection information for your local database. This is delegated to ActiveRecord. See [See ActiveRecord#Base::establish_connection](http://api.rubyonrails.org/classes/ActiveRecord/Base.html#method-c-establish_connection) for more details.

## Usage

Install the gem:

    gem install mir
  
Create mir_settings.yml in the HOME or /etc/mir directories. Adjust to taste

Push your local directory to S3
  
    mir ~/mydirectory
  
To retrieve your remote directory
  
    mir -c ~/mydirectory

## Notes

This project is considered in an alpha state and is not ready for use in any sort of production environment. Additionally, this has an embarrassingly small number of specs which should encourage you not to use this for your critical storage needs. 