$(document).ready(function() {
  moment.lang('en', {
      'calendar' : {
        'lastDay' : '[Yesterday]',
        'sameDay' : '[Today]',
        'nextDay' : 'D MMMM',
        'lastWeek' : 'dddd',
        'nextWeek' : 'D MMMM',
        'sameElse' : 'MMMM D'
        }
  });
    
  $("[moment-format='calendar']").each(function() {
    $(this).text( moment($(this).attr("utc")).calendar());
  });  
  
  $("[moment-format='fromNow']").each(function() {
    $(this).text( moment($(this).attr("utc")).fromNow());
  });  
});