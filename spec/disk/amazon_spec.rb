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
    
  it "should default to 5mb chunk size for uploads" do
    disk = Mir::Disk::Amazon.new(settings)
    disk.chunk_size.should == 5*2**20
  end
  
end