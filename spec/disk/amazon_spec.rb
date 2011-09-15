require "spec_helper"

describe Mir::Disk::Amazon do
  
  let(:settings) do
    {
      :bucket_name        => "bucket",
      :access_key_id      => "xxx",
      :secret_access_key  => "xxx"
    }
  end
  
  let(:disk) { Mir::Disk::Amazon.new(settings) }
    
  it "should default to 50mb chunk size for uploads" do
    disk = Mir::Disk::Amazon.new(settings)
    disk.chunk_size.should == 50*2**20
  end
  
  it "should use a chunked copy when files exceed the chunk size limit" do
    big_file = mock("foo", :size => disk.chunk_size + 1)
    File.should_receive(:new).and_return(big_file)
    disk.write(big_file)
  end
  
  describe "uploading files" do

  end
  
end