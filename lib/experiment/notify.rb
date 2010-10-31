class Notify
  def self.method_missing(meth, *args, &blk)
    $stdout.sync = true
    $stdout.send meth, *args, &blk
  end
end