require "spec_helper"

describe Mir::Index do
  
  describe "#update" do
    let(:index) { Mir::Index.new("/tmp", {}) }
    let(:fake_file) { mock("file", :directory? => false) }
    let(:resource) { mock("resource") }
    
    before(:each) do
      Mir::Models::AppSetting.should_receive(:last_indexed_at=)
      Dir.should_receive(:glob).and_yield("filename")
      File.should_receive(:new).and_return(fake_file)
      resource.should_receive(:update_attribute).and_return(true)
      index.stub!(:last_indexed_at)
    end
    
    it "adds an asset to the index if it has not yet been added" do
      Mir::Models::Resource.should_receive(:find_by_filename).and_return(nil)
      Mir::Models::Resource.should_receive(:create_from_file_and_name).and_return(resource)
      index.update
    end
    
    it "should flag a resource if the local copy is out of sync with the index" do
      Mir::Models::Resource.should_receive(:find_by_filename).and_return(resource)
      resource.should_receive(:synchronized?).and_return(false)
      resource.should_receive(:flag_for_update).and_return(true)
      index.update
    end
  end
  

end