class Endomondo
  def initialize(user_token)
    @http = HTTPClient.new
    @http.cookie_manager.parse("USER_TOKEN=#{user_token};", URI('https://www.endomondo.com'))
  end

  def get_recent_workouts
    (0..2).map {|page|
      res = @http.get(url_for_page(page))
      throw "Failed to fetch endomondo workouts! Possibly expired user token"  unless res.status == 200
      parse_workouts(res.body)
    }.flatten
  end
  
  private

  def url_for_page(i) 
    if i == 0 
      "https://www.endomondo.com/workouts/list/"
    else
      "https://www.endomondo.com/?wicket:interface=:0:pageContainer:lowerSection:lowerMain:lowerMainContent:results:navigator:navigation:#{i}:pageLink::IBehaviorListener:0:2"
    end
  end

  def parse_workouts(body)
    Nokogiri::HTML(body).css('tbody.compareShadow tr.row').map {|row|
      date = Date.parse(row.css('td:nth-child(2) span').inner_text)
      sport = row.css('td:nth-child(4) span').inner_text
      distance = row.css('td:nth-child(5) span').inner_text.to_f
      [date, distance, sport]
    }.select {|w|
      w[2].include?('Cycling')
    }.map {|w|
      Workout.new(*(w.shift(2)))
    }
  end
end
