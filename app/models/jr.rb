class Jr
  def self.exec
    start = Time.now
    jr = Jr.new
    driver = jr.driver
    from_day = 1
    to_day   = 7
    2.upto(jr.ws_log.max_rows).each do |log_row_i|
      from_day.upto(to_day).each do |day|
        puts "day is #{day}"
        Jr.new(driver: driver, day: day, log_row_i: log_row_i).exec
      end
    end
    sec = Time.now - start
    puts "#{sec} seconds."
  end

  def initialize(driver: nil, day: 1, log_row_i: 2)
    @driver = driver
    @col_i = day + 1
    date = "2020-1-#{day}".to_date
    wday = '日月火水木金土'.split('')[date.wday]
    wday = '水・祝' if [1,13].include?(day)
    t    = date.today? ? '【本日】' : ''
    @date = "#{t}1月#{day}日（#{wday}）"
    puts @date
    @time = '6:00'

    @start_name = ws_log[log_row_i, 2]
    @start_code = name2code[@start_name]
    @goal_name  = ws_log[log_row_i, 3]
    @goal_code  = name2code[@goal_name]
    @sheet_title = "#{@start_name}→#{@goal_name}"
  end


  def name2code
    @name2code ||= get_name2code
  end

  def get_name2code
    res = {}
    _ws = ws_stations
    2.upto(_ws.max_rows).each do |row_i|
      code =  format("%03d", _ws[row_i, 1])
      name = _ws[row_i, 2]
      res[name] = code
    end
    res
  end

  def driver
    if ENV['RPA_HEADLESS'].present?
      user_agent = 'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; WOW64; Trident/6.0)'
      @driver ||= Watir::Browser.new(:chrome, headless: true, options: { args: ["--user-agent=\"#{user_agent}\""] })
    else
      @driver ||= Watir::Browser.new(:chrome)
    end
  end

  def get_ws(sheet_name)
    ss.worksheet_by_title(sheet_name)
  end

  def ss
    key = '1r4tADlGU2v7mspnJOxeLnVk5QcUnZ3Nf7fFzWE8mOWE'
    @ss ||= Api::Google.new.gdrive.spreadsheet_by_key(
      key
    )
  end

  def ws
    @ws ||= ss.worksheet_by_title(@sheet_title)
  end

  def ws_log
    ws_log ||= get_ws('log')
  end

  def ws_stations
    ws_stations ||= get_ws('stations')
  end

  def exec
    login
    goto_yoyaku
    input_goal

    time = @time
    select_goal

    loop do
      if @time == time || time.split(':').first.to_i > 22
        row_i = 2
        col_i = 5
        Time.zone = 'Tokyo'
        ws_log[row_i, col_i] = Time.zone.now 
        ws_log.save
        return time
      else
        exec
        time = @time
      end
    end
  end

  def time2row_i
    @time2row_i ||= get_time2row_i
  end

  def get_time2row_i
    res = {}
    return res if ws.max_rows < 2
    2.upto(ws.max_rows).each do |row_i|
      time = ws[row_i, 1]
      res[time] = row_i
    end
    res
  end

  def select_goal
    goals = driver.articles(class: 'train-list')

    goals.each do |goal|
      dia1 = goal.div(class: 'dia-1').dl(class: 'dep').dt.text
      i1 = dia1.match(/([0-9][0-9]?).([0-9]{2})/)
      if goal.div(class: 'dia-2').present?
        dia2 = goal.div(class: 'dia-2').dl(class: 'dep').dt.text
        i2 = dia2.match(/([0-9][0-9]?).([0-9]{2})/)
        @time = "#{i1[1]}:#{i1[2]},#{i2[1]}:#{i2[2]}"
      else
        @time = "#{i1[1]}:#{i1[2]}"
      end

      row_i = time2row_i[@time]

      if row_i.blank?
        @time2row_i[@time] = ws.max_rows + 1
        row_i = time2row_i[@time]
      else
        # next # only new row
      end

      goal.p(class: 'start-button').click

      eco   = driver.divs(class: 'economy-long').select do |div|
        div.text.present? 
      end.first.ps.first.text
      green = driver.divs(class: 'green-long').select do |div|
        div.text.present? 
      end.first.ps.first.text

      puts "eco: #{eco}"
      puts "green: #{green}"

      result = '無'
      if eco != '×'
        result = '有'
      elsif green != '×'
        result = 'グ'
      end

      # return driver if result == '有'

      puts "#{@time}: #{result}"
      driver.span(id: 'l-6').click

      ws[row_i, 1] = @time
      ws[row_i, @col_i] = result

      ws.save
    end
   
    if driver.a(id: 'l-2').present?
      begin
        driver.a(id: 'l-2').click
      rescue
        sleep 1
        driver.span(id: 'l-6').click
        driver.a(id: 'l-2').click
      end
      select_goal
    else
      return
    end
  end

  def input_goal
    driver.select_list(id: 's-2').select(@date)

    hour_str = format("%02d", @time.split(':').first)
    driver.select_list(id: 's-3').select(hour_str)
    driver.select_list(id: 's-4').select('00')
    driver.select_list(id: 's6').select(@start_code)
    driver.select_list(id: 's7').select(@goal_code)
    driver.button(id: 'sb-1').click
  end


  def goto_yoyaku
    driver.a(name: 'b-1').click
  end

   def login
    driver.goto ENV['JR_WEST_URL']
    driver.text_field(id: 'pw-1').set(ENV['JR_WEST_PASS'])
    driver.button(id: 'sb-2').click
  end
end
