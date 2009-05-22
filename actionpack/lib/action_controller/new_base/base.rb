module ActionController
  class Base < Http
    abstract!
    
    include AbstractController::Benchmarker
    include AbstractController::Callbacks
    include AbstractController::Logger

    include ActionController::Helpers
    include ActionController::HideActions
    include ActionController::UrlFor
    include ActionController::Redirector
    include ActionController::Renderer
    include ActionController::Renderers::Json
    include ActionController::Renderers::Xml
    include ActionController::Renderers::Rjs
    include ActionController::Layouts
    include ActionController::ConditionalGet

    # Legacy modules
    include SessionManagement
    include ActionDispatch::StatusCodes
    include ActionController::Caching
    include ActionController::MimeResponds

    # Rails 2.x compatibility
    include ActionController::Rails2Compatibility

    include ActionController::Cookies
    include ActionController::Session
    include ActionController::Flash
    include ActionController::Verification
    include ActionController::RequestForgeryProtection
    include ActionController::Streaming
    include ActionController::HttpAuthentication::Basic::ControllerMethods
    include ActionController::HttpAuthentication::Digest::ControllerMethods
    include ActionController::FilterParameterLogging
    include ActionController::Translation

    # TODO: Extract into its own module
    # This should be moved together with other normalizing behavior
    module ImplicitRender
      def process_action(method_name)
        ret = super
        default_render if response_body.nil?
        ret
      end

      def default_render
        render
      end

      def method_for_action(action_name)
        super || begin
          if view_paths.find_by_parts?(action_name.to_s, {:formats => formats, :locales => [I18n.locale]}, controller_path)
            "default_render"
          end
        end
      end
    end

    include ImplicitRender

    include ActionController::Rescue

    def self.inherited(klass)
      ::ActionController::Base.subclasses << klass.to_s
      super
    end
    
    def self.subclasses
      @subclasses ||= []
    end
    
    def self.app_loaded!
      @subclasses.each do |subclass|
        subclass.constantize._write_layout_method
      end
    end
    
    def _normalize_options(action = nil, options = {}, &blk)
      if action.is_a?(Hash)
        options, action = action, nil 
      elsif action.is_a?(String) || action.is_a?(Symbol)
        key = case action = action.to_s
        when %r{^/} then :file
        when %r{/}  then :template
        else             :action
        end        
        options.merge! key => action
      elsif action
        options.merge! :partial => action
      end
      
      if options.key?(:action) && options[:action].to_s.index("/")
        options[:template] = options.delete(:action)
      end

      if options[:status]
        options[:status] = interpret_status(options[:status]).to_i
      end

      options[:update] = blk if block_given?
      options
    end

    def render(action = nil, options = {}, &blk)
      options = _normalize_options(action, options, &blk)
      super(options)
    end

    def render_to_string(action = nil, options = {}, &blk)
      options = _normalize_options(action, options, &blk)
      super(options)
    end

    # Redirects the browser to the target specified in +options+. This parameter can take one of three forms:
    #
    # * <tt>Hash</tt> - The URL will be generated by calling url_for with the +options+.
    # * <tt>Record</tt> - The URL will be generated by calling url_for with the +options+, which will reference a named URL for that record.
    # * <tt>String</tt> starting with <tt>protocol://</tt> (like <tt>http://</tt>) - Is passed straight through as the target for redirection.
    # * <tt>String</tt> not containing a protocol - The current protocol and host is prepended to the string.
    # * <tt>:back</tt> - Back to the page that issued the request. Useful for forms that are triggered from multiple places.
    #   Short-hand for <tt>redirect_to(request.env["HTTP_REFERER"])</tt>
    #
    # Examples:
    #   redirect_to :action => "show", :id => 5
    #   redirect_to post
    #   redirect_to "http://www.rubyonrails.org"
    #   redirect_to "/images/screenshot.jpg"
    #   redirect_to articles_url
    #   redirect_to :back
    #
    # The redirection happens as a "302 Moved" header unless otherwise specified.
    #
    # Examples:
    #   redirect_to post_url(@post), :status=>:found
    #   redirect_to :action=>'atom', :status=>:moved_permanently
    #   redirect_to post_url(@post), :status=>301
    #   redirect_to :action=>'atom', :status=>302
    #
    # When using <tt>redirect_to :back</tt>, if there is no referrer,
    # RedirectBackError will be raised. You may specify some fallback
    # behavior for this case by rescuing RedirectBackError.    
    def redirect_to(options = {}, response_status = {}) #:doc:
      raise ActionControllerError.new("Cannot redirect to nil!") if options.nil?

      status = if options.is_a?(Hash) && options.key?(:status)
        interpret_status(options.delete(:status))
      elsif response_status.key?(:status)
        interpret_status(response_status[:status])
      else
        302
      end

      url = case options
      # The scheme name consist of a letter followed by any combination of
      # letters, digits, and the plus ("+"), period ("."), or hyphen ("-")
      # characters; and is terminated by a colon (":").
      when %r{^\w[\w\d+.-]*:.*}
        options
      when String
        request.protocol + request.host_with_port + options
      when :back
        raise RedirectBackError unless refer = request.headers["Referer"]
        refer
      else
        url_for(options)
      end
      
      super(url, status)
    end
  end
end
