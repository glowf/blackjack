require 'rubygems'
require 'sinatra'
require 'json'

use Rack::Session::Cookie, :key => 'rack.session', :path => '/', :secret => 'glowf'

BLACKJACK = 21
DEALER_HIT_REQUIREMENT = 17
BALANCE = 500

helpers do
  def deck
    session[:deck]
  end

  def deck=(cards)
    session[:deck] = cards
  end

  def hand_player
    session[:player_cards]
  end

  def hand_player=(cards)
    session[:player_cards] = cards
  end

  def hand_dealer
    session[:dealer_cards]
  end

  def hand_dealer=(cards)
    session[:dealer_cards] = cards
  end

  def balance
    session[:balance]
  end

  def balance=(bal)
    session[:balance] = bal
  end

  def player_name
    session[:player]
  end

  def player_name=(name)
    session[:player] = name
  end

  def bet
    session[:bet]
  end

  def bet=(val)
    session[:bet] = val
  end

  def hand_total(cards)
    total = cards.collect {|card| card[2]}.inject(:+)
    total += 10 if cards.collect {|card| card[0]}.include?('a') && (total-1) <= 10
    total
  end

  def deduct_bet
    self.balance -= bet
  end

  def return_bet
    self.balance += bet
  end

  def surrender
    self.balance += bet/2
  end

  def deal(hand)
    hand << deck.pop
  end

  def valid_bet?(bet)
    bet <= balance && bet > 0
  end

  def bankrupt?
    balance == 0
  end

  def blackjack?(hand)
    hand_total(hand) == 21 && hand.size == 2
  end

  def build_deck
    suits = ['d','h','s','c']
    card_values = (('2'..'10').to_a + ['j','q','k','a']).product(suits)
    card_values.each do |card|
      fv = card[0]
      if fv == 'a' then card << 1
      elsif fv.to_i == 0 then card << 10 # if J, Q, K
      else card << fv.to_i
      end
    end
    card_values # [facevalue, suit, actual value]
  end

  def initial_cards
    self.hand_dealer,self.hand_player = [], []
    2.times do
      deal(hand_dealer)
      deal(hand_player)
    end
  end
end

get '/' do
  if !player_name || bankrupt?
    redirect '/username'
  else
    redirect '/game'
  end
end

get '/username' do
  erb  :username
end

post '/getplayername' do
  self.balance  = BALANCE
  if params[:name].empty?
    @error = "Name is required"
    halt erb(:username)
  end
  self.player_name = params[:name].capitalize
  redirect '/game'
end

get '/game/new' do
  self.player_name = nil
  redirect 'username'
end

get '/game' do
  self.bet = 0 if bet.nil?
  if bet > 0
    @result   = nil
    self.deck = [] if deck.nil?
    self.deck = deck.size > 20 ? deck  : build_deck.shuffle!
    initial_cards
    redirect '/game/results' if (blackjack?(hand_player) || blackjack?(hand_dealer)) && !request.xhr? #if anyone gets a blackjack (21 with 2 cards), get results asap
  end
  erb :game, layout: !request.xhr?
end

post '/game' do
  bet_input = params[:bet].to_i
  if !valid_bet?(bet_input)
    @error = "Invalid Bet. You have $#{balance} left."
    halt erb :game
  end
  self.bet = bet_input
  deduct_bet
  redirect '/game'
end

post '/game/playermove' do
  case params[:move].downcase
  when 'hit'
    redirect '/game/player/hit'
  when 'stay'
    redirect '/game/player/stay'
  when 'surrender'
    redirect '/game/player/surrender'
  when 'double down'
    redirect '/game/player/doubledown'
  end
end

get '/game/player/hit' do
  if hand_total(hand_player) < BLACKJACK
    deal(hand_player)
    redirect '/game/results' if hand_total(hand_player) >= BLACKJACK && !request.xhr?
  end
  if request.xhr?
     my_hash = {:cards => hand_player.last ,
                :round => "player",
                :total => hand_total(hand_player)}
     JSON.generate(my_hash, quirks_mode: true)
  else
    erb :game
  end
end

get '/game/player/stay' do
  redirect '/game/dealersmove'
end

get '/game/player/surrender' do
  surrender
  @result = "surrender"
  erb :game, layout: !request.xhr?
end

get '/game/player/doubledown' do
  if valid_bet?(bet)
    deduct_bet
    self.bet += bet
    if !request.xhr?
      deal(hand_player)
      redirect '/game/dealersmove'
    end
  end
end

get '/game/dealersmove' do
  if request.xhr?
     if hand_total(hand_dealer) < DEALER_HIT_REQUIREMENT
       deal(hand_dealer)
       cards = hand_dealer.last
     else
       cards = []
     end
     my_hash = {:cards =>  cards,
                :round => "dealer",
                :total => hand_total(hand_dealer)}
     JSON.generate(my_hash, quirks_mode: true)
  else
     while hand_total(hand_dealer) < DEALER_HIT_REQUIREMENT do
      deal(hand_dealer)
     end
     redirect '/game/results'
  end
end

get '/game/results' do
  player_total = hand_total(hand_player)
  dealer_total = hand_total(hand_dealer)
  @result = if blackjack?(hand_player) &&  !blackjack?(hand_dealer)
              "blackjack"
            elsif !blackjack?(hand_player) &&  blackjack?(hand_dealer)
              "dealer"
            elsif player_total > BLACKJACK
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
  if bet > 0  #make sure no money is added if user hits refresh
    case @result
      when "player"
        self.balance += bet * 2
      when "blackjack"
        self.balance += bet * 3
      when "push"
        return_bet
    end
    self.bet = 0
  end

  if request.xhr?
     my_hash = {:result => @result, :balance => balance }
     JSON.generate(my_hash, quirks_mode: true)
  else
    erb :game
  end
end
