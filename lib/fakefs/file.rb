module FakeFS
  class File
    PATH_SEPARATOR = '/'

    MODES = [
      READ_ONLY           = "r",
      READ_WRITE          = "r+",
      WRITE_ONLY          = "w",
      READ_WRITE_TRUNCATE = "w+",
      APPEND_WRITE_ONLY   = "a",
      APPEND_READ_WRITE   = "a+"
    ]

    def self.extname(path)
      RealFile.extname(path)
    end

    def self.join(*parts)
      parts * PATH_SEPARATOR
    end

    def self.exist?(path)
      !!FileSystem.find(path)
    end

    class << self
      alias_method :exists?, :exist?
    end

    def self.size(path)
      read(path).length
    end

    def self.const_missing(name)
      RealFile.const_get(name)
    end

    def self.directory?(path)
      if path.respond_to? :entry
        path.entry.is_a? FakeDir
      else
        result = FileSystem.find(path)
        result ? result.entry.is_a?(FakeDir) : false
      end
    end

    def self.symlink?(path)
      if path.respond_to? :entry
        path.is_a? FakeSymlink
      else
        FileSystem.find(path).is_a? FakeSymlink
      end
    end

    def self.file?(path)
      if path.respond_to? :entry
        path.entry.is_a? FakeFile
      else
        result = FileSystem.find(path)
        result ? result.entry.is_a?(FakeFile) : false
      end
    end

    def self.expand_path(*args)
      RealFile.expand_path(*args)
    end

    def self.basename(*args)
      RealFile.basename(*args)
    end

    def self.dirname(path)
      RealFile.dirname(path)
    end

    def self.readlink(path)
      symlink = FileSystem.find(path)
      FileSystem.find(symlink.target).to_s
    end

    def self.open(path, mode=READ_ONLY, perm = 0644)
      if block_given?
        yield new(path, mode, perm)
      else
        new(path, mode, perm)
      end
    end

    def self.read(path)
      file = new(path)
      if file.exists?
        file.read
      else
        raise Errno::ENOENT
      end
    end

    def self.readlines(path)
      read(path).split("\n")
    end

    attr_reader :path
    def initialize(path, mode = READ_ONLY, perm = nil)
      check_mode(mode)

      @path = path
      @mode = mode
      @file = FileSystem.find(path)
      @open = true

      file_creation_mode? ? create_missing_file : check_file_existence!
    end

    def close
      @open = false
    end

    def read
      raise IOError.new('closed stream') unless @open
      @file.content
    end

    def exists?
      @file
    end

    def puts(*content)
      content.flatten.each do |obj|
        write(obj.to_s + "\n")
      end
    end

    def write(content)
      raise IOError, 'closed stream' unless @open
      raise IOError, 'not open for writing' if read_only?

      create_missing_file
      @file.content += content
    end
    alias_method :print, :write
    alias_method :<<, :write

    def flush; self; end

  private

    def check_file_existence!
      unless @file
        raise Errno::ENOENT, "No such file or directory - #{@file}"
      end
    end

    def read_only?
      @mode == READ_ONLY
    end

    def file_creation_modes
      MODES - [READ_ONLY, READ_WRITE]
    end

    def file_creation_mode?
      file_creation_modes.include?(@mode)
    end

    def check_mode(mode)
      if !MODES.include?(mode)
        raise ArgumentError, "illegal access mode #{mode}"
      end
    end

    def create_missing_file
      if !File.exists?(@path)
        @file = FileSystem.add(path, FakeFile.new)
      end
    end
  end
end
