var angularController = angular.module('angularController', []);

angularController.controller('angularSearch', function ($scope) {
	$scope.fields = [
	                 {text:'Abstract', value:'abstract='},
	                 {text:'Date Last Changed',value:'datelastchanged='},
	                 {text:'DDC',value:'ddc='},
	                 {text:'Department',value:'department='},
	                 {text:'Document type',value:'documenttype='},
	                 {text:'External Identifier',value:'externalidentifier='},
	                 {text:'ISBN',value:'isbn='},
	                 {text:'ISSN',value:'issn='},
	                 {text:'Keywords', value:'keyword='},
	                 {text:'Non-UniBi publication',value:'extern=1'},
	                 {text:'Person',value:'person='},
	                 {text:'PUB-ID',value:'id='},
	                 {text:'Publication is popular science',value:'popularscience=1'},
	                 {text:'Publication Status',value:'publicationstatus='},
	                 {text:'Publications with fulltext',value:'fulltext=1'},
                     {text:'Publishing year',value:'publishingyear='},
                     {text:'Title', value:'title='},
	                 ];
	$scope.operators = [
	                    {text:'AND (default)', value:'AND'},
	                    {text:'OR', value:'OR'},
	                    {text:'NOT', value:'NOT'},
	                    {text:'"Exact phrase"', value:'"exact phrase"'},
	                    {text:'*', value:'*'}
	                    ];
	$scope.addField = function(myVal) {
		if(myVal){
			if(!$scope.yourQuery){
				$scope.yourQuery = myVal;
			}
			else{
				var res = $scope.yourQuery.match(/AND\s?$|OR\s?$|NOT\s?$/);
				if(res && res != ""){
					$scope.yourQuery = $scope.yourQuery.trim();
					$scope.yourQuery += " " + myVal;
				}
				else {
					$scope.yourQuery += " AND " + myVal;
				}
			}
		}
	};
	
	$scope.addOperator = function(myVal) {
		if(myVal){
			if($scope.yourQuery){
				if(myVal == '"exact phrase"'){
					$scope.yourQuery += ' AND ' + myVal;
				}
				else if(myVal == "*"){
					$scope.yourQuery += myVal + " ";
				}
				else {
					$scope.yourQuery += " " + myVal + " ";
				}
			}
			else if(myVal == "NOT"){
				$scope.yourQuery = myVal + " ";
			}
			else if(myVal == '"exact phrase"'){
				$scope.yourQuery = myVal;
			}
		}
	};
	
	
	
	var language = $('#language_id').text();
	if(language == ""){language = "de"};
	
	var lang = {
			en:{
				tabs:{
					home:"Home",
					publication:"Publications",
					data:"Data Publications",
					projects:"Projects",
					authors:"Authors",
					theses:"PUB Theses",
					about:"About PUB",
				},
				home: {
					heading: "PUB – The Publication Server at Bielefeld University",
					stats_publication:{
						text:"Publications",
						link:"/publication?lang=en",
					},
					stats_pubpeople:{
						text:"Individual Author Pages",
						link:"/person?lang=en",
					},
					stats_researchdata:{
						text:"Data Publications",
						link:"/data?lang=en",
					},
					stats_oahits:{
						text:"Open Access Publications",
						link:"/publication?lang=en&fulltext=1",
					},
					stats_theseshits:{
						text:"Theses",
						link:"/publication?lang=en&publicationtype=bi*",
					},
				},
				search:{
					button_go: "Go!",
					button_fields: "Fields",
					button_operators: "Operators",
					placeholder_home: "Search UniBi Publications",
					placeholder_other: "Search",
				},
			},
			de:{
				tabs:{
					home:"Home",
					publication:"Publikationen",
					data:"Datenpublikationen",
					projects:"Projekte",
					authors:"Autoren",
					theses:"PUB Theses",
					about:"Über PUB",
				},
				home: {
					heading: "PUB – Der Publikationenserver der Universität Bielefeld",
					stats_publication:{
						text:"Publikationen",
						link:"/publication",
					},
					stats_pubpeople:{
						text:"Persönliche Publikationslisten",
						link:"/person",
					},
					stats_researchdata:{
						text:"Datenpublikationen",
						link:"/data",
					},
					stats_oahits:{
						text:"Open Access Publikationen",
						link:"/publication?fulltext=1",
					},
					stats_theseshits:{
						text:"Hochschulschriften",
						link:"/publication?publicationtype=bi*",
					},
				},
				search:{
					button_go: "Los!",
					button_fields: "Felder",
					button_operators: "Operatoren",
					placeholder_home: "UniBi Publikationen suchen",
					placeholder_other: "Suche",
				},
			},
	};
	
	$scope.lang = lang[language];
	
});
