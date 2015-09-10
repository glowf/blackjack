require 'rubygems'
require 'sinatra'

use Rack::Session::Cookie, :key => 'rack.session', :path => '/', :secret => 'glowf'
set :sessions, true

BLACKJACK = 21
DEALER_HIT_REQUIREMENT = 17
MONEY = 500

helpers do
  def add_cards(cards)
    total = cards.collect {|card| card[2]}.inject(:+)
    total += 10 if cards.collect {|card| card[0]}.include?('A') && total-1 <= 10
    total
  end

  def take_bet(bet, money=MONEY)
    session[:bet]    = bet.to_i
    session[:money]  = money - session[:bet]
  end

  def valid_bet?(bet)
    bet <= session[:money] && bet > 0
  end

  def bankrupt?
    session[:money] == 0
  end
end

before do
  @show_player_moves = true
end

get '/' do
  if !session[:player] || bankrupt?
    redirect '/username'
  else
    redirect '/game'
  end
end

get '/username' do
  erb  :username
end

post '/getplayername' do
  session[:money]  = MONEY
  if params[:name].empty?
    @error = "Name is required"
    halt erb(:username)
  elsif  !valid_bet?(params[:bet].to_i)
    @error = "Invalid Bet"
    halt erb(:username)
  end
  session[:player] = params[:name].capitalize
  take_bet(params[:bet])
  redirect '/game'
end

get '/game/new' do
  session[:player] = nil
  redirect 'username'
end

get '/game' do
  session[:deck], @result, session[:round] = [], nil, ""

  def build_deck
    suits = ['d','h','s','c']
    card_values = (('2'..'10').to_a + ['J','Q','K','A']).product(suits)
    card_values.each do |card|
      fv = card[0]
      if fv == 'A' then card << 1
      elsif fv.to_i == 0 then card << 10 # if J, Q, K
      else card << fv.to_i
      end
    end
    card_values # [facevalue, suit, actual value]
  end

  def initial_cards
    session[:dealer_cards], session[:player_cards] = [], []
    2.times do
      session[:dealer_cards] << session[:deck].pop
      session[:player_cards] << session[:deck].pop
    end
  end
  session[:deck] = session[:deck].size > 20 ? session[:deck] : build_deck.shuffle!
  initial_cards
  erb :game
end

post '/game' do
  if !valid_bet?(params[:bet].to_i)
    @error = "Invalid Bet. You have $#{session[:money] } left."
    @show_player_moves, @show_bet = false, true
    halt erb :game
  end
  take_bet(params[:bet],session[:money])
  redirect '/game'
end

post '/game/playermove' do
  case params[:move].downcase
  when 'hit'
    session[:player_cards] << session[:deck].pop
    redirect '/game/results' if add_cards(session[:player_cards]) > BLACKJACK
  when 'stay'
    redirect '/game/dealersmove'
  end
  erb :game
end

get '/game/dealersmove' do
  @show_player_moves = false
  while add_cards(session[:dealer_cards]) < DEALER_HIT_REQUIREMENT do
    session[:dealer_cards] << session[:deck].pop
  end
  redirect '/game/results'
  erb :game
end

get '/game/results' do
  @show_player_moves = false
  player_total = add_cards(session[:player_cards])
  dealer_total = add_cards(session[:dealer_cards])
  @result = if player_total > BLACKJACK
              "bust"
            elsif dealer_total > BLACKJACK
              "player"
            elsif player_total == dealer_total
              "push"
            elsif player_total > dealer_total
              "player"
            else
              "dealer"
            end
  if session[:round] == ""  #make sure no money is added if user hits refresh
    if @result == "player"
      session[:money] += session[:bet]*2 #return bet + winnings
    elsif @result == "push"
      session[:money] += session[:bet] #return bet
    end
    session[:round] = "done"
  end

  if bankrupt?
    @error = "You have no money left."
    @bankrupt = true
    halt erb :game
  end
  erb :game
end
