class Jr
  def initialize
  end

  def driver
    if ENV['RPA_HEADLESS'].present?
      user_agent = 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; WOW64; Trident/6.0)'
      @driver ||= Watir::Browser.new(:chrome, headless: true, options: { args: ["--user-agent=\"#{user_agent}\""] })
    else
      @driver ||= Watir::Browser.new(:chrome)
    end
  end

	def login
		driver.goto ENV['APLEX_URL']
	end
end
