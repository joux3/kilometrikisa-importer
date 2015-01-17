require 'json'

class Kilometrikisa
  LOGIN_URL = "https://www.kilometrikisa.fi/accounts/login/"
  WORKOUTS_URL = "https://www.kilometrikisa.fi/contest/log_list_json/11/?start=%s&end=%s"
  LOG_URL = "https://www.kilometrikisa.fi/contest/log/"
  SAVE_URL = "https://www.kilometrikisa.fi/contest/log-save/"

  def initialize(username, password, contest_id)
    @contest_id = contest_id
    @http = HTTPClient.new
    @http.get LOGIN_URL
    res = @http.post(LOGIN_URL, with_token({'next' => '', 'username' => username, 'password' => password}), {'Referer' => LOGIN_URL})
    throw "Failed to log into kilometrikisa!" unless res.status == 302
  end

  def get_entries_between(start_date, end_date)
    # add extra days around like the kilometrikisa JS does
    start_date -= 1
    end_date += 1
    res = @http.get(WORKOUTS_URL % [start_date.strftime('%s'), end_date.strftime('%s')])
    throw "Failed to fetch workouts from kilometrikisa!" unless res.status == 200
    JSON.parse(res.body).map{|wo|
      Workout.new(Date.parse(wo['start']), wo['title'].to_f)
    }
  end

  def save_workout(workout)
    res = @http.post(SAVE_URL, with_token({'contest_id' => @contest_id, 'km_amount' => workout.length, 'km_date' => workout.date.strftime('%Y-%m-%d')}), {'Referer' => LOG_URL, 'X-Requested-With' => 'XMLHttpRequest'})
    res.status == 200
  end

  private

  def with_token(data)
    data.tap { data['csrfmiddlewaretoken'] = csrftoken() }
  end

  def csrftoken
    token = @http.cookie_manager.cookies.select{|c| c.name == "csrftoken"}.first
    throw "Can't find CSRF!" unless token
    token.value
  end
end
