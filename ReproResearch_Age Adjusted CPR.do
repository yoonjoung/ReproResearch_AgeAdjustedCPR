clear 
clear matrix
clear mata
set more off
set mem 300m
set maxvar 9000


global 	directory 	"C:\Users\YoonJoung Choi\Dropbox\0 Project\ReproResearch_AgeAdjustedCPR"
cd		"$directory\"

*******************************************************************
*** 1. Data Access 
*******************************************************************

* 1.1. DEFINE relevant indicators for the study (only three indicators for this study)
/*
List of indicators are here: 
http://api.dhsprogram.com/rest/dhs/indicators?returnFields=IndicatorId,Label,Definition&f=html
*/
	
#delimit;
global indicatorlist " 
	FE_FRTR_W_TFR	  
	FP_CUSA_W_ANY	 
	MA_MSTA_W_UNI	 
	";
	#delimit cr		
		
#delimit;
global indicatorlist_minusone " 
	FP_CUSA_W_ANY	 
	MA_MSTA_W_UNI	 
	";
	#delimit cr		

* 1.2. CALL API data for each indicator and save each

foreach indicator in $indicatorlist{

	clear
	insheetjson using "http://api.dhsprogram.com/rest/dhs/data?indicatorIds=`indicator'&breakdown=all&APIkey=USAAID-113824&perpage=20000",	

		gen str9  surveyid=""
		gen str30 country=""	
		gen str20 group=""
		gen str20 grouplabel=""
		gen str5  value=""	

	#delimit; 	
	insheetjson surveyid country group grouplabel value 
	using  "http://api.dhsprogram.com/rest/dhs/data?indicatorIds=`indicator'&breakdown=all&APIkey=USAAID-113824&perpage=20000",	
	table(Data) 
	col(SurveyId CountryName CharacteristicCategory CharacteristicLabel Value);	
	#delimit cr

		destring value, replace	
		drop if value==.
		rename value `indicator'
			
		sort surveyid group grouplabel
			egen temp=group(surveyid group grouplabel)
			codebook temp
			sort temp
			drop if temp==temp[_n-1]
			drop temp
	
	sort surveyid group grouplabel
	save API_`indicator'.dta, replace	
	
	}
	
* 1.3. merge the three indicator datasets, starting from the first indicator 
	
use API_FE_FRTR_W_TFR.dta, clear	
	sort surveyid group grouplabel
	
	foreach indicator in $indicatorlist_minusone{	
	 
		merge surveyid group grouplabel using API_`indicator'	
			codebook _merge* 
			drop _merge*	
			
		sort surveyid group grouplabel
	}

sort country 	
save dtaapi, replace	

	codebook country surveyid
	/*number of unique surveys and countries*/	

*******************************************************************
*** 2. Data Management  
*******************************************************************
	
* 2.1. Rename, Check, and Recode etc.  
	
use dtaapi, clear 
				
	rename FE_FRTR_W_TFR  tfr
	rename FP_CUSA_W_ANY  cpr_all
	rename MA_MSTA_W_UNI  inunion

	replace group ="Total" if group=="Total 15-49"
	replace grouplabel ="Total" if grouplabel=="Total 15-49"
	
	gen year=substr(surveyid,3,4)  
		destring year, replace	
		label var year "year of survey"
	gen type=substr(surveyid,7,3) 	
		label var type "type of survey"
		tab year type, m
	gen period2=0 
		replace period2=1  if year>=2001
		lab define period2 1"1985-2000" 2"2001-2015"
		lab values period2 period2		
		
keep if type=="DHS"
keep if group=="Total" | group=="Age (5-year groups)"

	*Because inunion group label was different, they are in a differnt row from CPR row... i.e., there were two total rows... 
	tab grouplabel group if inunion!=., m
	tab grouplabel group if cpr_all==., m

	sort surveyid group grouplabel
	list surveyid group grouplabel cpr inunion
	
	capture drop temp*
	gen temp1=inunion if group=="Total"
	egen temp2=mean(temp1), by(surveyid)
	replace inunion=temp2 if group=="Total" & inunion==.
	format inunion %12.1f
	drop temp*
	
drop if cpr_all==.	

	sort country 
	
save dta, replace	

* 2.2. Create regional category variables
/*
"Subregion Name" according to the DHS categories are same with UNSD subregion names 
EXCEPT for one country: Sudan, which is not included in the paper.  
Thus, use that for now. 
*/

	clear
	insheetjson using "http://api.dhsprogram.com/rest/dhs/countries",	

		gen str30 country=""	
		gen str30 DHSsubregion=""

	#delimit; 			
	insheetjson country DHSsubregion  
	using  "http://api.dhsprogram.com/rest/dhs/countries",	
	table(Data) 
	col(CountryName SubregionName);	
	#delimit cr
	
	sort country

save DHSsubregion, replace

use dta, clear 
	merge country using DHSsubregion
		tab _merge
			tab country if _merge~=3
		keep if _merge==3
		drop _merge

	gen region5=""
		replace region5="SSA, Central and Western" if ///
			DHSsubregion=="Western Africa" | ///
			DHSsubregion=="Middle Africa"
		replace region5="SSA, Southern and Eastern" if /// 
			DHSsubregion=="Eastern Africa" | /// 
			DHSsubregion=="Southern Africa"	 
		replace region5="MENACAEE" if ///
			DHSsubregion=="Eastern Europe"| ///
			DHSsubregion=="North Africa"| ///
			DHSsubregion=="Southern Europe"| ///
			DHSsubregion=="West Asia"
		replace region5="Asia" if ///
			DHSsubregion=="Central Asia"| ///
			DHSsubregion=="South Asia"| ///
			DHSsubregion=="Southeast Asia"
		replace region5="LAC" if ///
			DHSsubregion=="Caribbean" | ///
			DHSsubregion=="Central America" | ///
			DHSsubregion=="South America"
			
	gen region2="SSA" if ///
			DHSsubregion=="Western Africa" | ///
			DHSsubregion=="Middle Africa" | ///
			DHSsubregion=="Eastern Africa" | /// 
			DHSsubregion=="Southern Africa"	 	
			
save dta, replace		

* 2.3. Create age-adjusted CPR

use dta, clear 
	gen grouplabelnum=.
		replace grouplabelnum=17 if group=="Age (5-year groups)" & grouplabel=="15-19" 
		replace grouplabelnum=22 if group=="Age (5-year groups)" & grouplabel=="20-24" 
		replace grouplabelnum=27 if group=="Age (5-year groups)" & grouplabel=="25-29" 
		replace grouplabelnum=32 if group=="Age (5-year groups)" & grouplabel=="30-34" 
		replace grouplabelnum=37 if group=="Age (5-year groups)" & grouplabel=="35-39"
		replace grouplabelnum=42 if group=="Age (5-year groups)" & grouplabel=="40-44" 
		replace grouplabelnum=47 if group=="Age (5-year groups)" & grouplabel=="45-49"			
	local num=17
	while `num'<50{
		gen temp=cpr_all		if grouplabelnum==`num'
		egen temp_`num' = mean(temp), by(surveyid)
		drop temp 
		local num = `num' + 5
		}	
	egen aacpr_all=rowtotal(temp_17 - temp_47) 
	replace aacpr_all= 5*aacpr_all/35
	drop temp_*
			
keep if group=="Total" 	
save dtasum, replace	

* 2.4. Create variables to quantify relationship between unadjusted vs. age-adjusted CPR
	
	gen ratio_cpr	=aacpr_all / cpr_all 
	lab var ratio_cpr "ratio: AACPR/CPR" 
	lab var aacpr_all "age-adjusted CPR, among all women"
	
save dtasum, replace	

* 2.5. Keep analysis sample

	*For the purpose of reproducing the results, 
	*Drop newly released surveys since September 2017.
	*They are likely surveys conducted in 2014, 2015 or later
	#delimit;
	gen byte newsurvey=
		year>=2017	|
		(year==2016 & (surveyid!="AM2016DHS" & surveyid!="ET2016DHS" & surveyid!="MM2016DHS")) |
		(year==2015 & (surveyid!="CO2015DHS" & surveyid!="GU2015DHS" 
						& surveyid!="MW2015DHS" & surveyid!="RW2015DHS" 
						& surveyid!="TZ2015DHS" & surveyid!="ZW2015DHS" 
						& surveyid!="AO2015DHS")) |
		(year==2014 & (surveyid!="BD2014DHS" & surveyid!="EG2014DHS" 
						& surveyid!="GH2014DHS" & surveyid!="KE2014DHS" 
						& surveyid!="KH2014DHS" & surveyid!="LS2014DHS" 
						& surveyid!="SN2014DHS" & surveyid!="TD2014DHS"))
		;
		#delimit cr

drop if newsurvey==1		

save dtasum, replace	

	codebook country surveyid
	/*number of unique surveys and countries*/
	/*SHOULD be "259 surveys from 85 countries <== ANALYSIS SAMPLE"*/

*******************************************************************
*** 3. Data Analysis   
*******************************************************************

/*
There are four tables and one figure in results. 
The following presents code for the tables and the figure in the order of 
their appearance in the paper.
*/

* 3.1. Table 1

use dtasum, clear 

	egen countryid=group(country) 	
	
	* with two periods
	gen g2 = (period2==1)
	gen g2cpr_all 		= g2*cpr_all
 
	* ALL countries  
	xtreg tfr cpr_all if g2==0, i(countryid)
	xtreg tfr cpr_all if g2==1, i(countryid)	
	xtreg tfr cpr_all g2 g2cpr_all, i(countryid)
		test g2 g2cpr_all	

	* SSA only 
	keep if region2=="SSA"  		
	xtreg tfr cpr_all if g2==0, i(countryid)
	xtreg tfr cpr_all if g2==1, i(countryid)	
	xtreg tfr cpr_all g2 g2cpr_all, i(countryid)
		test g2 g2cpr_all
		
* 3.2. Table 2

use dtaapi, clear 
keep if surveyid=="DR2013DHS" | surveyid=="EG2014DHS" 
keep if group=="Age (5-year groups)"

	sort surveyid group grouplabel
	list surveyid group grouplabel FP_CUSA_W_ANY

use dtasum, clear 
keep if surveyid=="DR2013DHS" | surveyid=="EG2014DHS" 

	sort surveyid 
	list surveyid cpr_all aacpr_all ratio_cpr
	
* 3.3. Figure 1

*** Upper figure among all countries
use dtasum, clear 

	egen countryid=group(country) 	
	xtreg ratio_cpr cpr_all, i(countryid)
	predict yhat
	
	gen overall="Overall"
	
	#delimit; 
	twoway scatter yhat ratio_cpr cpr_all, 
		
		by(overall, legend(off) note(""))
		yline(1, lcolor(navy) lpattern(-))	
		ytitle("Ratio of age-adjusted CPR to unadjusted CPR", size(small))	
		xtitle("CPR (%), among all women", size(small))
		msymbol(i o) mcolor(navy navy) msize(small small) 
		connect(l) lcolor(navy)
		xlab(, labsize(small))
		ylab(0.8(0.1) 1.3, labsize(small))
		xsize(6) ysize(4)
		;
		#delimit cr				
			
	gr_edit .style.editstyle boxstyle(shadestyle(color(white))) editcopy	
	gr_edit .legend.style.editstyle boxstyle(linestyle(color(white))) editcopy
						
	gr_edit .plotregion1.subtitle.style.editstyle fillcolor(white) editcopy
	gr_edit .plotregion1.subtitle.style.editstyle linestyle(color(white)) editcopy

	gr_edit .style.editstyle boxstyle(linestyle(color(gs3))) editcopy
	gr_edit .style.editstyle boxstyle(linestyle(align())) editcopy		
			
*** Lower figure by region 
use dtasum, clear 

	egen countryid=group(country) 	
			
	gen ratio_cpr_SSACW=ratio_cpr if region5=="SSA, Central and Western" 
	gen ratio_cpr_SSASE=ratio_cpr if region5=="SSA, Southern and Eastern"
	gen ratio_cpr_MENACAEE=ratio_cpr if region5=="MENACAEE"
	gen ratio_cpr_Asia=ratio_cpr if region5=="Asia" 	
	gen ratio_cpr_LAC=ratio_cpr if region5=="LAC"

	gen region4=region5
		replace region4="Asia, Middle East, Europe" if region5=="Asia" | region5=="MENACAEE" 
		
	gen yhat=.
		
		xtreg ratio_cpr cpr_all if region4=="Asia, Middle East, Europe" , i(countryid)	
		predict temp if region4=="Asia, Middle East, Europe"
		sum temp
		replace yhat=temp if yhat==.
		drop temp
		
		xtreg ratio_cpr cpr_all if region4=="LAC" , i(countryid)	
		predict temp if region4=="LAC"
		sum temp
		replace yhat=temp if yhat==.
		drop temp
		
		xtreg ratio_cpr cpr_all if region4=="SSA, Central and Western" , i(countryid)	
		predict temp if region4=="SSA, Central and Western"
		sum temp
		*replace yhat=temp if yhat==.
		drop temp
		
		xtreg ratio_cpr cpr_all if region4=="SSA, Southern and Eastern" , i(countryid)	
		predict temp if region4=="SSA, Southern and Eastern"
		sum temp
		replace yhat=temp if yhat==.
		drop temp			
	
	#delimit; 
	twoway scatter yhat ratio_cpr_* cpr_all, 
		by(region4, 
			legend(off) 
			note("Orange circle: South and South East Asia" "Green circle: Middle East, Central Asia, and Eastern Europe", size(small)) 
			)
		yline(1, lcolor(navy) lpattern(-))	
		ytitle("Ratio of age-adjusted CPR to unadjusted CPR", size(small))	
		xtitle("CPR (%), among all women", size(small))
		xlab(, labsize(small))
		ylab(0.8(0.1)1.3, labsize(small))
		msymbol(i)
		msize(small 	 small small small small small)
		mcolor(black 	 navy cranberry green orange midblue)		
		connect(l)
		xsize(6) ysize(4)
		;
		#delimit cr	
				
	gr_edit .style.editstyle boxstyle(shadestyle(color(white))) editcopy	
	gr_edit .plotregion1.plotregion1[1].style.editstyle boxstyle(linestyle(color(bluishgray))) editcopy	
	
	gr_edit .plotregion1.subtitle[1].style.editstyle fillcolor(white) linestyle(color(white)) size(medlarge)  editcopy		
	gr_edit .legend.style.editstyle boxstyle(linestyle(color(white))) editcopy
	
	gr_edit .style.editstyle boxstyle(linestyle(color(gs3))) editcopy
	gr_edit .style.editstyle boxstyle(linestyle(align())) editcopy		
	
* 3.4. Table 3

use dtasum, clear 

	egen countryid=group(country) 	
	tab region5, gen(region5_)
	
	xtreg tfr  cpr_all, i(countryid)
	xtreg tfr  aacpr_all, i(countryid) 

	xtreg tfr  cpr_all 	 inunion region5_* , i(countryid)
	xtreg tfr  aacpr_all inunion region5_* , i(countryid) 

* 3.5. Table 4

	bysort period2: xtreg tfr  cpr_all, i(countryid)
	bysort period2: xtreg tfr  aacpr_all, i(countryid) 

	bysort period2: xtreg tfr  cpr_all 	 inunion region5_* , i(countryid)
	bysort period2: xtreg tfr  aacpr_all inunion region5_* , i(countryid) 
	
*******************************************************************
*** END OF DO FILE 
*******************************************************************
