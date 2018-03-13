#!ruby
# encoding: utf-8

require 'rubygems'
require 'bundler/setup'
require 'levenshtein'
require 'fileutils'
require 'logger'
require 'date'
require './shoboi_renamer'

class File
  def self.append(filename, text,**msg)
    File.open(filename, 'a',msg){|f| f.write(text)}
  end
end

class TsSorter
  SortedDir=%q'Y:/aaa/' #to
  UnsortDir=%q'Y:/' #from
  RenameDir=%q'Y:/_comp/_end/_move/'
  CurrentFile=SortedDir+'current.txt'
  MovedFile  =SortedDir+'moved.txt'
  ServiceName={
    "BSジャパン" => "BS Japan" ,
    "NHKBSプレミアム" => "NHK BSプレミアム",
    "BSフジ・181" => "BSフジ",
    "NHK総合・東京"=> "NHK総合",
    "NHKEテレ東京" => "NHK Eテレ",
    "BS11イレブン" => "BS11デジタル",
    "BS朝日1" => "BS朝日",
    "フジテレビジョン" => "フジテレビ",
  }

  def initialize()
    Encoding.default_external = 'UTF-8'
    @logger = Logger.new(SortedDir+'logfile.cvs')
    @logger.formatter = proc{|severity, datetime, progname, message|
        %("#{datetime}"\t#{severity}\t"#{message}"\n)
    }
    make_dirnames
    @renamer=nil
  end
  
  def make_dirnames
    @org_names= File.readlines(CurrentFile,encoding: 'utf-8')
    @dir_names= @org_names.map{|v| v.sub(/[　 \r\n\t]*(\[.*\]_第\d+話.*)?$/,'').sub(/^[　 \r\n\t]*/,'').strip }.delete_if{|v| v==''}
  end
  def error(str)
    puts str
    @logger.error str
  end
  def info(str)
    puts str
    @logger.info str
  end

  def sort
    Dir.glob(UnsortDir+'*.ts').each do |filename|
      basename=File.basename(filename).sub(/[　 \r\n\t]*\[.*\]_第\d+話.*$/,'')
      score,dirname=@dir_names.inject([0.5,nil])do|ret,dirname|
        score=Levenshtein.normalized_distance(basename,dirname)
        (score<ret[0]) ? [score,dirname] : ret
      end
      mes="#{score}\t#{dirname}\t#{filename}"
      
      if dirname then
        path=SortedDir+dirname
        Dir.mkdir(path) unless Dir.exist?(path)
        FileUtils.mv(filename,path)
        FileUtils.rm(filename+'.meta') if File.exist?(filename+'.meta')
        info mes
      else
        @logger.debug mes
      end
    end
    self
  end

  def renamer
    @renamer||=ShoboiRenamer.new(ServiceName,@logger)
    @renamer
  end
  def check_final
    #renamer=ShoboiRenamer.new(ServiceName,@logger)
    current=[]
    moved=[]
    @dir_names.zip(@org_names).each do |dirname,orgname|
      flg_moded=false
      path=SortedDir+dirname
      mv_dirname=RenameDir+dirname
      if Dir.exist?(path)
        t =Time.now - (10*24*60*60)
        ret=Dir.glob(path+'/*.ts').reduce(true) do |flg,item|
          s = File::Stat.new(item).mtime
          flg && (t > s)
        end
        if ret
          info "最終回\t#{dirname}"
          if Dir.exist?(mv_dirname)
            info "Already exist\t#{mv_dirname}"
          else
            renamer.rename_title(path)
            FileUtils.mv(path,mv_dirname)
            flg_moded=true
         end
        end
      else
          info "移動済\t#{dirname}"
          flg_moded=true
      end
      if flg_moded
        moved << "#{Time.now}\t#{orgname}"
      else
        current << "#{orgname}"
      end
    end
    if moved.size > 0
      File.write(CurrentFile,current.join,encoding: 'utf-8')
      File.append(MovedFile,moved.join,encoding: 'utf-8')
    end
    self
  end
end

if $0 == __FILE__
  TsSorter.new().sort.check_final
end

__END__
