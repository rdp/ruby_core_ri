require 'rbconfig'
require 'tempfile'
require 'tmpdir'
require 'yaml'
require File.join(File.dirname(__FILE__), 'contrib', 'uri_ext')
require 'archive/tar/minitar'
require 'zlib'
require 'fileutils'
require 'backports' # Dir.mktmpdir

module Ruby_core_source

# params
# hdrs: proc 
# ex: proc { have_header("vm_core.h") and have_header("iseq.h") }
# name: string (config name for makefile)
#
def create_makefile_with_core(hdrs, name)
  #
  # First, see if the needed headers already exist somewhere
  #
  if hdrs.call
    create_makefile(name)
    return true
  end

  dest_dir = download_headers hdrs
  
  with_cppflags("-I" + dest_dir) {
    if hdrs.call
      create_makefile(name)
      return true
    end
  }
  return false
end


#
# returns the location of headers downloaded and extracted from source
# you can pass it a specific dest_dir if you don't want it at the default location
# and can specify just_headers = false
# if you want all the source files to be downloaded there, not just *.{h, inc}
#
def download_headers hdrs, dest_dir = nil, just_headers = true, existing_pre_unpacked_dir = nil

  ruby_dir = ""
  ruby_version = RUBY_VERSION[0..-3]
  
  if RUBY_VERSION >= '1.9'
    puts "Warning: if this fails, you may need to install rdp-rdoc gem until rdoc > 2.4.3 gem is available"    
  end

  if RUBY_PATCHLEVEL < 0
    # some type of svn checkout
    # try to use mark's lookup
    Tempfile.open("preview-revision") { |temp|
      uri = URI.parse("http://cloud.github.com/downloads/mark-moseley/ruby_core_source/preview_revision.yml")
      uri.download(temp)
      revision_map = YAML::load(File.open(temp.path))
      ruby_dir = revision_map[RUBY_REVISION]
      return false if ruby_dir.nil?
    }
  else

    version = RUBY_VERSION.to_s
    patch_level = RUBY_PATCHLEVEL.to_s      
    ruby_dir = "ruby-" + version + "-p" + patch_level
  end


  #
  # Download the source headers
  #
  uri_path = "http://ftp.ruby-lang.org/pub/ruby/" + ruby_version + "/" + ruby_dir + ".tar.gz"
  Tempfile.open("ruby-src") { |temp|
    temp.binmode
    uri = URI.parse(uri_path)
    unless existing_pre_unpacked_dir
      uri.download(temp)
      tgz = Zlib::GzipReader.new(File.open(temp.path, 'rb'))
    end

    FileUtils.mkdir_p(dest_dir)
    Dir.mktmpdir { |dir|
      dir = existing_pre_unpacked_dir if existing_pre_unpacked_dir
      Archive::Tar::Minitar.unpack(tgz, dir) unless existing_pre_unpacked_dir
      if just_headers
        inc_dir = dir + "/" + ruby_dir + "/*.inc"
        hdr_dir = dir + "/" + ruby_dir + "/*.h"
        glob = [inc_dir, hdr_dir]
        FileUtils.cp(Dir.glob(glob), dest_dir)
      else
        FileUtils.cp_r(Dir.glob(dir + "/" + ruby_dir + "/*"), dest_dir)
      end
      
    }
  }
  dest_dir
end

module_function :create_makefile_with_core
module_function :download_headers

end
