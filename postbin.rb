require 'rubygems'
require 'sinatra'
require 'haml'
require 'sass'
require 'digest/md5'

get '/' do
  purge_old_postbins
  haml :welcome, :locals => { :postbin_name => generate_postbin_name }
end

get '/stylesheet.css' do
  headers 'Content-Type' => 'text/css; charset=utf-8'
  sass :stylesheet
end

get '/:id' do
  haml :show_posts, :locals => { :posts => (@@storage[params[:id]] || {})[:posts] }
end

post '/:id' do
  store_post(params[:id])
  haml :post_created, :locals => { :name => params[:id] }
end


get '/flash/clippy.swf' do
  send_file "#{Sinatra::Application.root}/flash/clippy.swf", :disposition => 'inline', :type => 'application/x-shockwave-flash'
end

def create_postbin
  loop do
    name = generate_postbin_name
    break unless @@storage.keys.include?(name)
  end
  
  @@storage[name] = []
  name
end

def generate_postbin_name
  Digest::MD5.hexdigest("#{Time.now}#{Time.now.usec}")[0..6]
end

def store_post(name)
  @@storage[name] ||= {}
  @@storage[name][:posts] ||= []
  @@storage[name][:last_post_at] = Time.now
  @@storage[name][:posts] << { :data=>request.body.read, :time=>Time.now, :headers=>request.http_headers }
  @@storage
  # debugger
end

def init_storage
  @@storage ||= Hash.new
end

def purge_old_postbins(expiration = (24*60*60))
  @@storage.each_key do |k|
    @@storage.delete(k) if @@storage[k][:last_post_at] < Time.now - expiration
  end
end

class Sinatra::Request
  def http_headers
    out = env.clone
    out.delete_if { |k,v| !k.match(/^HTTP_/) }
    out
  end
end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
  
  def distance_of_time_in_words(from_time, to_time=Time.now)
    diff = (from_time - to_time).abs
    if diff < 60
      "#{diff.round} seconds"
    elsif diff > (60 * 60)
     "#{(diff / 60 / 60).round} hours"
    elsif diff < (60 * 60)
      "#{(diff / 60).round} minutes"
    end
  end

  def clippy(text, bgcolor='#FFFFFF')
    html = <<-EOF
      <object classid="clsid:d27cdb6e-ae6d-11cf-96b8-444553540000"
              width="110"
              height="14"
              id="clippy" >
      <param name="movie" value="/flash/clippy.swf"/>
      <param name="allowScriptAccess" value="always" />
      <param name="quality" value="high" />
      <param name="scale" value="noscale" />
      <param NAME="FlashVars" value="text=#{text}">
      <param name="bgcolor" value="#{bgcolor}">
      <embed src="/flash/clippy.swf"
             width="110"
             height="14"
             name="clippy"
             quality="high"
             allowScriptAccess="always"
             type="application/x-shockwave-flash"
             pluginspage="http://www.macromedia.com/go/getflashplayer"
             FlashVars="text=#{text}"
             bgcolor="#{bgcolor}"
      />
      </object>
    EOF
  end
end
init_storage

