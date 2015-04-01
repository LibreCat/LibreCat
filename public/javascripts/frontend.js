$(function () {
	$('.mark').click(function(evt) {
		evt.preventDefault();
		var a = $(this);
		var marked = a.data('marked');
		if (marked == 0) {
			$.post('/mark/'+a.data('id'), function(res) {
				$('.total-marked').text(res.total);
				a.data('marked', 1);
				a.children('span').removeClass('fa-square-o');
				a.children('span').addClass('fa-check-square-o');
			}, 'json');
		}
		else {
			$.post('/mark/'+a.data('id')+'?x-tunneled-method=DELETE', function(res) {
				$('.total-marked').text(res.total);
				a.data('marked', 0);
				a.children('span').removeClass('fa-check-square-o');
				a.children('span').addClass('fa-square-o');
			}, 'json');
			if(a.attr('id') && /clickme_(\d{1,})/i.test(a.attr('id'))){
				var indexes = a.attr('id').match(/clickme_\d{1,}/i);
				indexes[0] = indexes[0].replace(/clickme_/,"");
				$('#fade_' + indexes[0]).fadeOut('slow', function() {});
			}
		}
	});
});

$( document ).ready(function() {
    $.post('/marked_total', function(res) {
    	$('.total-marked').text(res.total);
    });
});