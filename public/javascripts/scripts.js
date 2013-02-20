// zusaetzlich json2.js (notwendig fuer IE)

function checkForm4Ddc() {
	var abstractField = document.getElementById('id_ab_abAbstract_1');
	var ddcButton = document.getElementById('suggestDdc');
	var languageList = document.getElementById('id_ab_abLanguageOId_1');
	if (abstractField.value.length >= 500 && (languageList.value=='190' || languageList.value=='196')){
		ddcButton.disabled= false;
	} else {
		ddcButton.disabled= true;
	}
}

function ajaxRequest() {
	
	var abstractField = document.getElementById('id_ab_abAbstract_1');
	var languageList = document.getElementById('id_ab_abLanguageOId_1');	
	var ddcField = document.getElementById('dw_dwDdcOId_1');
	var language;
	var ddcClass;
	var myRequest = null;
	
	//alert('Bitte beachten Sie: Der Vorgang dauert einige Sekunden!');
	loader();
	
	try {
		// Mozilla, Opera, Safari sowie Internet Explorer (ab v7)
	    myRequest = new XMLHttpRequest();
	} catch(e) {
	    try {
	        // MS Internet Explorer (ab v6)
	        myRequest  = new ActiveXObject("Microsoft.XMLHTTP");
	    } catch(e) {
	        try {
	            // MS Internet Explorer (ab v5)
	            myRequest  = new ActiveXObject("Msxml2.XMLHTTP");
	        } catch(e) {
	            myRequest  = null;
	            errMsg();
	        }
	    }
	}
	if (myRequest) {
		if (languageList.value=='190') language='en';
		if (languageList.value=='196') language='de';
		var params = "language=" + language + "&text=" + abstractField.value;
	    myRequest.open('POST', '/csljson/getDdc.php', true);
	  	//Send the proper header information along with the request
	    myRequest.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
	    myRequest.setRequestHeader("Content-length", params.length);
	    myRequest.setRequestHeader("Connection", "close");
	    //The onreadystatechange event is triggered every time the readyState changes.
	    //The readyState property holds the status of the XMLHttpRequest and Changes from 0 to 4.
	    //The onreadystatechange event is triggered four times, one time for each change in readyState
	    myRequest.onreadystatechange = function () {
	    	if(myRequest.readyState == 4) {
	    		if (myRequest.status == 200) {
		            var response = JSON.parse(myRequest.responseText);   
		        	var found = false;
		            unloader();
		            //z.B. if (response[3][110].confidence) funktioniert nicht richtig! Kein alert!
		            if ('3' in response && '0' in response[3]) {
		            	if(response[3][0].confidence < 0.5) {
		            		 errMsg();
		            	} 
		            	changeSelectColor();
		            	for (var i=1; i < ddcField.length; i++) {
		            		//ddc Klasse muss aus dem Text herausgelesen werden
		            		//ddcClass = ddcField[i].text;
		            		//ddcClass = ddcClass.replace(/[\D]/g, '');
		            		//ddcClass = ddcClass.substr(0,3);
		            		//ddc aus der id auslesen
		            		ddcClass = ddcField[i].id;
                            ddcClass = ddcClass.substr(3,3);
		            		//if (i==1) alert(ddcClass);            		            		
		            		if (ddcClass==response[3][0].number) {
		            			ddcField.options[i].selected=true;
		            			ddcField.options[i].style.color= '#F00';
		            			//muss gesezt werden, sonst wird das selected Feld nicht rot!
		            			ddcField.style.color = ddcField.options[i].style.color;
		            			found = true;
		            		} else {
		            			//sollte vorher schon mal ddc klase ermittelt worden sein, muss sie wieder auf schwarz gesetzt werden
		            			ddcField.options[i].style.color= '#000';
		            		}
		            	}
		            } 
	    		}
		    	if (!found) {
		    		errMsg();
		    	}
	    	}
	    };
	    myRequest.send(params);
	}
}

function changeSelectColor() {
	var ddcField = document.getElementById('dw_dwDdcOId_1');
	ddcField.style.color = '#000';
}

function errMsg() {
	unloader();
	alert('Es konnte keine DDC-Klasse ermittelt werden!');
	return;	
}

function loader() {
	// Breite und Höhe des Maskierungs-DIV's auslesen 
	var divH = document.getElementById('loader-mask').offsetHeight;
	var divW = document.getElementById('loader-mask').offsetWidth;

	// Linke und obere Position des Loader GIF berechnen und setzen 
	var imgTop = (divH / 2) - (document.getElementById('loadergif').height / 2);
	var imgLeft = (divW / 2) - (document.getElementById('loadergif').width / 2);
	document.getElementById('loadergif').style.left = imgLeft + "px";
	document.getElementById('loadergif').style.top = imgTop + "px";

	// dislay="hidden" vom Bild löschen 
	document.getElementById('loadergif').style.display = "";

	// den transparenten DIV einblenden und höhe und breite setzen 
	document.getElementById('loader').style.width = divW + "px";
	document.getElementById('loader').style.height = divH + "px";
	document.getElementById('loader').style.display = "";
}

function unloader() {
	// alles zurücksetzen und ausblenden 
	document.getElementById('loader').style.width = "0px";
	document.getElementById('loader').style.height = "0px";
	document.getElementById('loader').style.display = "none";
	document.getElementById('loadergif').style.display = "none";
}


