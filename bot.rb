#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'slack-ruby-client'
require 'json'
load './config.ru'

team = TEAM_ID
team_short = TEAM_SHORT
season = SEASON
channel = SLACK_CHANNEL

Slack.configure do |config|
  config.token = API_TOKEN
end

#Determines number of spaces needed for quarter
def check_quarter(score)
        if score > 9
                if score < 100
                        return 2
                else
                        return 1
                end
        else
                return 3
        end
end

#Determines number of spaces needed for final
def check_final(score)
        if score > 99
                return 5
        else
                return 6
        end
end


#gameid="0021700046"
def get_game(gameid)
	url = URI.parse("http://stats.nba.com/stats/boxscoresummaryv2/?GameID=#{gameid}")
	req = Net::HTTP::Get.new(url)
	req['Accept-Language'] = 'en-US,en;q=0.8'
	req['Upgrade-Insecure-Requests'] =  '1'
	req['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/61.0.3163.100 Safari/537.36'
	req['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8'
	req['Cache-Control'] = 'max-age=0'
	req['Cookie: s_cc=true'] =  's_fid=668A9A1A2DE9E558-3B8DA9609553CC63; s_sq=%5B%5BB%5D%5D'
	req['Connection'] =  'keep-alive'
	http = Net::HTTP.new(url.host, url.port)
	begin
		http.set_debug_output $stdout	
		res = http.request(req)
	rescue 
		retry
	end
	return res.body
end

def get_season(team,season)
	url = URI.parse("http://stats.nba.com/stats/TeamGameLog/?TeamID=#{team}&Season=#{season}&SeasonType=Regular%20Season")
	req = Net::HTTP::Get.new(url)
	req['Accept-Language'] = 'en-US,en;q=0.8'
	req['Upgrade-Insecure-Requests'] =  '1'
	req['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/61.0.3163.100 Safari/537.36'
	req['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8'
	req['Cache-Control'] = 'max-age=0'
	req['Cookie: s_cc=true'] =  's_fid=668A9A1A2DE9E558-3B8DA9609553CC63; s_sq=%5B%5BB%5D%5D'
	req['Connection'] =  'keep-alive'
	http = Net::HTTP.new(url.host, url.port)
	begin
		http.set_debug_output $stdout	
		res = http.request(req)
	rescue 
		retry
	end
	return res.body
end



teamsum = JSON.load(get_season(team,season))
games_source = File.open('games.json', 'r')
games = JSON.load(games_source)
games_source.close
record_source = File.open('record.json','r')
record = JSON.load(record_source)
record_source.close

client = Slack::Web::Client.new
client.auth_test
teamsum["resultSets"][0]["rowSet"].each do |game|
	if ! games.include?(game[1])
		boxscore = JSON.load(get_game(game[1]))
		if boxscore["resultSets"][0]["rowSet"][0][4] == "Final"
			games << game[1]
			gamestats = boxscore["resultSets"][5]

			#Build tables
			#Figure out top row
			team1arr = gamestats["rowSet"][0]
			team1 = "|#{team1arr[4]}   |"
			team1q1 = "#{team1arr[8]}" + " " * check_quarter(team1arr[8]) + "|"
			team1q2 = "#{team1arr[9]}" + " " * check_quarter(team1arr[9]) + "|"
			team1q3 = "#{team1arr[10]}" + " " * check_quarter(team1arr[10]) + "|"
			team1q4 = "#{team1arr[11]}" + " " * check_quarter(team1arr[11]) + "|"
			team1f = "#{team1arr[-1]}" + " " * check_final(team1arr[-1]) + "|"
			#Bottom Row
			team2arr = gamestats["rowSet"][1]
			team2 = "|#{team2arr[4]}   |"
			team2q1 = "#{team2arr[8]}" + " " * check_quarter(team2arr[8]) + "|"
			team2q2 = "#{team2arr[9]}" + " " * check_quarter(team2arr[9]) + "|"
			team2q3 = "#{team2arr[10]}" + " " * check_quarter(team2arr[10]) + "|"
			team2q4 = "#{team2arr[11]}" + " " * check_quarter(team2arr[11]) + "|"
			team2f = "#{team2arr[-1]}" + " " * check_final(team2arr[-1]) + "|"
		
			#Check which team won
			if team1arr[-1] > team2arr[-1]
				if team1arr[4] == team_short
					record["wins"] += 1
				else
					record["losses"] += 1
				end
			else
				if team2arr[4] == team_short
					record["wins"] += 1
				else
					record["losses"] += 1
				end
			end
		
			client.channels_setTopic(channel: "#{channel}", topic: "Season Record: #{record["wins"]}-#{record["losses"]} | #{team2arr[4]} #{team2arr[-1]} - #{team1arr[4]} #{team1arr[-1]}")
			client.chat_postMessage(channel: "#{channel}",
			text:"```-------------------------------------\n"\
			"| Team | Q1 | Q2 | Q3 | Q4 | FINAL  |\n"\
			"#{team1}#{team1q1}#{team1q2}#{team1q3}#{team1q4}#{team1f}\n"\
			"#{team2}#{team2q1}#{team2q2}#{team2q3}#{team2q4}#{team2f}\n"\
			"-------------------------------------```\n"\
			"http://www.nba.com/spurs/stats/team", as_user: true)
		end
	end
end

games_source = File.open('games.json', 'w')
games_source.write(games.to_json)
games_source.close
record_source = File.open('record.json', 'w')
record_source.write(record.to_json)
record_source.close
