$(function () {
	$('a.mark').click(function(evt) {
		alert('got here');
		evt.preventDefault();
		var a = $(this);
		var marked = a.data('marked');
		if (marked == 0) {
			$('div.unmark_all').empty().append('<a class="unmark-all" href="#">Unmark all</a>');
			$.post('/mark/'+a.data('id'), function(res) {
				$('.total-marked').text(res.total);
				a.data('marked', 1).text('Unmark');
			}, 'json');
		}
		else {
			$.post('/mark/'+a.data('id')+'?x-tunneled-method=DELETE', function(res) {
				$('.total-marked').text(res.total);
				a.data('marked', 0).text('Mark');
			}, 'json');
			if($('.total-marked').text() == "1") {
				$('div.unmark_all').empty();
			}
		}
	});
});