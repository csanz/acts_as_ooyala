module LocusFocus
  module Ooyala
    module Helper
      
      def embed_ooyala(video, opts = {}, html_opts = {})
        begin
          video = Video.find(video) if video.is_a?(String)
        rescue LocusFocus::Ooyala::RequestExpired
          return "Request Expired."
        end
          timestamp =  ("%10.5f" % Time.now.to_f).to_i
          options = {
            :width => video.width,
            :height => video.height,
            :embedCode => video.embed_code,
            :autoplay => 0,
            :playerId => "ooyalaPlayer_#{timestamp}",
            :loop => 0
          }.merge(opts)
          
          html_options = {
            :id => "ooyalaPlayer_#{timestamp}",
            :name => "ooyalaPlayer_#{timestamp}",
            :quality => "high",
            :bgcolor => "#000000"
          }.merge(html_opts)
        
        %Q(
        <script src="http://www.ooyala.com/player.js?#{options.to_query}"></script>
        <noscript>
            <object classid="clsid:D27CDB6E-AE6D-11cf-96B8-444553540000" 
              id="#{html_options[:id]}" 
              width="#{options[:width]}"
              height="#{options[:height]}"
              codebase="http://fpdownload.macromedia.com/get/flashplayer/current/swflash.cab">
                  <param name="movie" value="http://www.ooyala.com/player.swf" />
                  <param name="quality" value="#{html_options[:quality]}" />
                  <param name="bgcolor" value="#{html_options[:bgcolor]}" />
                  <param name="allowScriptAccess" value="always" />
                  <param name="allowFullScreen" value="true" />
                  <param name="flashvars" value="#{options.to_query}" />
                  <embed src="http://www.ooyala.com/player.swf" 
                    quality="#{html_options[:quality]}"
                    bgcolor="#{html_options[:bgcolor]}"
                    width="#{options[:width]}"
                    height="#{options[:height]}"
                    name="#{html_options[:name]}"
                    align="middle" 
                    play="true" 
                    loop="false" 
                    allowscriptaccess="always" 
                    allowfullscreen="true" 
                    type="application/x-shockwave-flash" 
                    flashvars="#{options.to_query}"
                    pluginspage="http://www.adobe.com/go/getflashplayer">
                  </embed>
            </object>
        </noscript>
        ).gsub(/\n/, "").squeeze(' ')
      end
    end
  end
end