$(document).ready(function(){

  var BLACKJACK  = 21,
      DEALER_HIT = 17;

  var btn_hit       = "#btn-move-hit",
      btn_stay      = "#btn-move-stay",
      btn_dd        = "#btn-move-dd",
      btn_surrender = "#btn-move-surrender",
      bet_chip      = ".list-bets a",
      btn_deal      = "#btn-deal",
      btn_clear_bet = "#btn-clear-bet";

  var div_player = "#box-player",
      div_dealer = "#box-dealer",
      div_game   = "#game",
      div_bet    = "#box-bet";

  var bet_amount      = "#bet-amount",
      balance_amount  = "#balance-amount",
      bet_display     = ".bet p",
      balance_display = ".balance p";

  chips_toggle(); //in case of refresh

  $('html').addClass('js');

  // Add listeners to buttons
  $('body').on("click", btn_hit, function() {
    $("#box-actions-additional").hide();
    player_hit();
    return false;
  });

  $('body').on("click", btn_stay, function() {
    dealer_hit();
    return false;
  });

  $('body').on("click", btn_dd, function() {
    hide_actions();
    player_dd();
    return false;
  });

  $('body').on("click", btn_surrender,  function() {
    player_surrender();
    return false;
  });

  $('body').on("click", bet_chip, function() {
    add_bet(parseInt($(this).text()));
    if (current_bet() > 0) { disable_bet_actions(false); }
    return false;
  });

  $('body').on("click", btn_deal,  function() {
    $(this)
     .text('Dealing...')
     .prop("disabled", true);
    deal_again();
    return false;
  });

  $('body').on("click", btn_clear_bet ,  function() {
    clear_bet();
    return false;
  });

  function player_hit(is_dd) {
    is_dd = is_dd || false; // if hit is caused by double down
    $.ajax({
        type: 'get',
        url:   '/game/player/hit',
        dataType: 'json',
        }).done(function(data){
          show_card(data, div_player);
          if ((data.total == BLACKJACK || is_dd) && $(btn_stay).trigger( 'click' ));
          if (data.total > BLACKJACK) {
            hide_actions();
            process_result();
          }
      });
  }

  function player_dd() {
    update_balances(current_balance()-current_bet(),current_bet()*2);
    $.ajax({
      type: 'get',
      url:   '/game/player/doubledown'
      }).done(function(){
        player_hit(true);
    });
  }

  function player_surrender() {
     hide_actions();
    $.ajax({
      type: 'get',
      url:   '/game/player/surrender',
      dataType: 'html',
      }).done(function(data){
        $(div_game).replaceWith(data);
        show_result("surrender");
        update_balances(current_balance(), 0);
        $(div_bet).fadeIn(500);
         hide_actions();
    });
  }

  function dealer_hit() {
    $("#blank-card").remove();
    hide_actions();
    $.ajax({
        type: 'get',
        url:   '/game/player/stay',
        dataType: 'json'
      }).done(function(data){
       window.setTimeout(function() {
         $(".box-dealer > .total").text(data.total).show();
         if (($(data.cards).length != 0) && show_card(data, div_dealer));
         (data.total >= DEALER_HIT) ? process_result() : dealer_hit();
       }, 1000);
    });
  }

  function deal_again(){
    var new_bet = current_bet();
     $.ajax({
        type: 'post',
        url:   '/game',
        dataType: 'html',
        data: {bet: new_bet}
      }).done(function(data){
        $(div_game).replaceWith(data);
        check_player_blackjack();
     });
  }

  function process_result(){
    $.ajax({
        type: 'get',
        url:   '/game/results',
        dataType: 'json'
      }).done(function(data){
          show_result(data.result);
          $(div_bet).fadeIn(500);
          update_balances(data.balance, 0);
          if ((data.balance == 0) && bankrupt());
     });
  }

  function show_card(data, div_id){
    var card = data.cards[0] + data.cards[1];
    var new_card = $("<li><span class='card card-" + card +"'></span></li>").fadeIn(500);
    $(div_id).find('.list-cards').append(new_card);
    $(div_id).find('.total').text(data.total).show();
  }

  function show_result(result){
    $('.text-result').addClass('text-'+result);
    $('.box-result').fadeIn(1000);
    $(div_game).addClass('result-shown');
  }

  function hide_actions(){
    $(".box-actions").hide();
  }

  function update_balances(balance, bet){
    $(bet_display).hide().text('$'+bet).fadeIn(200);
    $(balance_display).hide().text('$'+balance).fadeIn(200);
    $(bet_amount).val(bet);
    $(balance_amount).val(balance);
    chips_toggle();
  }

  function add_bet(amount){
    var bet = current_bet() + amount;
    var balance =  current_balance() - amount;
    update_balances(balance, bet);
  }

  function clear_bet(){
    disable_bet_actions(true);
    update_balances((current_balance() + current_bet()), 0);
    chips_toggle();
  }

  function current_bet(){
    return parseInt($(bet_amount).val());
  }

  function current_balance(){
    return parseInt($(balance_amount).val());
  }

  function disable_bet_actions(enabled){
    $(btn_deal).prop("disabled", enabled);
    $(btn_clear_bet).prop("disabled", enabled);
  }

  function chips_toggle(){
    var chips = ['.chip-10', '.chip-20','.chip-50', '.chip-100'];
    $.each( chips, function( i, chip ) {
      if (parseInt($(chip).text()) > current_balance()){
        $(chip).addClass('disable');
        $(chip).bind('click', false);
       } else {
        $(chip).removeClass('disable');
        $(chip).unbind('click', false);
       }
    });
  }

  //once the first two cards are dealt, immediately check for a blackjack
  function check_player_blackjack(){
    var total = parseInt($(div_player).find('.total').text());
    if (total == 21){
      hide_actions();
      process_result();
    }
  }

  function bankrupt(){
    $(div_bet).hide();
    $("#box-gameover").show();
  }

});
