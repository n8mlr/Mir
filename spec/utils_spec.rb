require "spec_helper"
require "tempfile"
require "fileutils"
require "digest/md5"

describe Mir::Utils do
  
  context "Splitting files" do
    before(:all) do
      @tmp_dir = "/tmp/splitter-tests"
      FileUtils.mkdir(@tmp_dir) unless File.exist? @tmp_dir
      @fake_file_path = "/tmp/512byteFile"
      @file = open(@fake_file_path, "w") do |f|
        f.write <<-EOS
          Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor 
          incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud 
          exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute 
          irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla 
          pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia 
          deserunt mollit anim id est laborum.
        EOS
      end
    end
    
    after(:all) do
      FileUtils.rm(Dir.glob(File.join(@tmp_dir, "*")))
      FileUtils.rm(@fake_file_path)
    end
    
    it "should create smaller files from one large file" do
      path = Mir::Utils.split_file(@fake_file_path, 8, @tmp_dir)
      split_files = Dir.glob(File.join(@tmp_dir, "*"))
      split_files.size.should == 64
    end
    
    it "should recombine smaller files into one large file" do
      dest = "/tmp/recombined.txt"
      path = Mir::Utils.recombine(@tmp_dir, dest)
      Digest::MD5.file(dest).should == Digest::MD5.file(@fake_file_path)
    end

  end
end