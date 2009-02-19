# =DoCoMo携帯電話

module Jpmobile::Mobile
  # ==DoCoMo携帯電話
  class Docomo < AbstractMobile
    autoload :IP_ADDRESSES, 'jpmobile/mobile/z_ip_addresses_docomo'
    autoload :DISPLAY_INFO, 'jpmobile/mobile/z_display_info_docomo'

    # 対応するUser-Agentの正規表現
    USER_AGENT_REGEXP = /^DoCoMo/
    # 対応するメールアドレスの正規表現
    MAIL_ADDRESS_REGEXP = /^.+@docomo\.ne\.jp$/
    # FOMA なのに XHTML をサポートしないモデル
    # http://www.nttdocomo.co.jp/service/imode/make/content/spec/index.html
    XHTML_UNSUPPORTED_MODEL_NAME = ["N2001", "N2002", "P2002", "D2101V", "P2101V", "SH2101V", "T2101V"]

    # オープンiエリアがあればエリアコードを +String+ で返す。無ければ +nil+ を返す。
    def areacode
      if params["ACTN"] == "OK"
        return params["AREACODE"]
      else
        return nil
      end
    end

    # 位置情報があれば Position のインスタンスを返す。無ければ +nil+ を返す。
    def position
      return @__position if defined? @__position
      lat = params["lat"] || params["LAT"]
      lon = params["lon"] || params["LON"]
      geo = params["geo"] || params["GEO"]
      return @__position = nil if ( lat.nil? || lat == '' || lon.nil? || lon == '' )
      raise "Unsuppoted datum" if geo.downcase != "wgs84"
      pos = Jpmobile::Position.new
      raise "Unsuppoted" unless lat =~ /^([+-]\d+)\.(\d+)\.(\d+\.\d+)/
      pos.lat = Jpmobile::Position.dms2deg($1,$2,$3)
      raise "Unsuppoted" unless lon =~ /^([+-]\d+)\.(\d+)\.(\d+\.\d+)/
      pos.lon = Jpmobile::Position.dms2deg($1,$2,$3)
      return @__position = pos
    end

    # 端末製造番号があれば返す。無ければ +nil+ を返す。
    def serial_number
      case @request.env["HTTP_USER_AGENT"]
      when /ser([0-9a-zA-Z]{11})$/ # mova
        return $1
      when /ser([0-9a-zA-Z]{15});/ # FOMA
        return $1
      else
        return nil
      end
    end
    alias :ident_device :serial_number

    # FOMAカード製造番号があれば返す。無ければ +nil+ を返す。
    def icc
      @request.env['HTTP_USER_AGENT'] =~ /icc([0-9a-zA-Z]{20})\)/
      return $1
    end

    # iモードIDを返す。
    def guid
      @request.env['HTTP_X_DCMGUID']
    end

    # iモードID, FOMAカード製造番号の順で調べ、あるものを返す。なければ +nil+ を返す。
    def ident_subscriber
      guid || icc
    end

    # 画面情報を +Display+ クラスのインスタンスで返す。
    def display
      @__display ||= Jpmobile::Display.new(nil,nil,
                            display_info[:browser_width],
                            display_info[:browser_height],
                            display_info[:color_p],
                            display_info[:colors])
    end

    # cookieに対応しているか？
    def supports_cookie?
      false
    end
    
    # XHTMLをサポートしているか。
    # FOMA でも一部の機種では XHTML をサポートしていない.
    def supports_xhtml?
      parse_user_agent
      if @generation >= 2.0
        if XHTML_UNSUPPORTED_MODEL_NAME.include?(@model_name)
          false
        else
          true
        end
      else
        false
      end
    end
    
    private
    # User-Agent を解析する.
    def parse_user_agent
      unless @user_agent_parsed
        if @request.user_agent =~ /^DoCoMo\/2.0 (.+)\(/
          @model_name = $1
          @generation = 2.0
        elsif @request.user_agent =~ /^DoCoMo\/1.0\/(.+?)\//
          @model_name = $1
          @generation = 1.0
        end
        @user_agent_parsed = true # 解析済みフラグ.
      end
    end
    
    # モデル名を返す。
    def model_name
      parse_user_agent
      @model_name
    end

    # 画面の情報を含むハッシュを返す。
    def display_info
      DISPLAY_INFO[model_name] || {}
    end
  end
end
