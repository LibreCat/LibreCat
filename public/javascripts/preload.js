// preloader message for publication lists
window.onload=fPreloader;

function fPreloader() { //DOM
	for (var i = 0; i < document.getElementsByName('preloader[]').length; i++) {
		if (document.getElementById){
			document.getElementById('preloader-'+i).style.visibility='hidden';
		} else {
			if (document.layers){ //NS4
				document.preloader.visibility = 'hidden';
			}
			else { //IE4
				document.all.preloader.style.visibility = 'hidden';
			}
		}
	}
}