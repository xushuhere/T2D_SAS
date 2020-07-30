
/*****************************************************************************************************/
/**************************** PLEASE DO NOT EDIT CODE BELOW THIS LINE ********************************/
/*****************************************************************************************************/

%let PACKAGENAME = RCR_T2D_PART_1;
%let ver         = v6_0;

proc printto log="&qpath.dmoutput/&DMID._&PACKAGENAME._&VER..log" new;
run;

data dmlocal.RUNTIME;
    length programs $20;
    format start_time end_time datetime19. processing_time time8.;
	array _char_ programs;
    array _num_  start_time end_time processing_time;
    programs="RCR_T2D";
    start_time=datetime();
    output;        
run;

proc sql;
CREATE TABLE dmlocal.T1712_RCRT2D_COUNT1 AS 
 SELECT PATID
FROM indata.DEMOGRAPHIC
where YRDIF(birth_date,&query_to,'AGE')>=18; 
quit;

/* Case 1: */

proc sql;
CREATE TABLE dmlocal.T1712_RCRT2D_COUNT2 AS 

SELECT PATID, INDEX_DATE format=date9., ENCOUNTERID, ENC_TYPE, MEDICATION,
DX AS ICD_CODE 
 FROM
 (
SELECT DIAG_ICD.PATID
		, CASE WHEN ADMIT_DATE> RX_ORDER_DATE THEN RX_ORDER_DATE
				ELSE ADMIT_DATE END as INDEX_DATE format=date9.
		
		, CASE WHEN ADMIT_DATE> RX_ORDER_DATE THEN MED.ENCOUNTERID
				ELSE DIAG_ICD.ENCOUNTERID END as ENCOUNTERID
				
		, CASE WHEN ADMIT_DATE> RX_ORDER_DATE THEN 'AV'
				ELSE DIAG_ICD.ENC_TYPE END as ENC_TYPE
		, RAW_RX_MED_NAME as MEDICATION
		, DX
		FROM
		(
		SELECT DISTINCT DIAG.PATID,  ADMIT_DATE
		, ENCOUNTERID ,ENC_TYPE
		, DIAG.DX
			FROM 
			indata.DIAGNOSIS DIAG
			WHERE DIAG.PATID IN (SELECT PATID FROM dmlocal.T1712_RCRT2D_COUNT1)
			AND ((DX_TYPE= '09' AND compress(DX, '.') IN (&CASE_ICD_09.))
				 OR
				(DX_TYPE= '10' AND compress(DX, '.') IN (&CASE_ICD_10.)))
			AND ENC_TYPE IN ('AV','IP','EI')
			AND ADMIT_DATE BETWEEN &query_from AND &query_to
			
			) DIAG_ICD
			

		,(SELECT RX.PATID, RX_ORDER_DATE, RX.ENCOUNTERID, RAW_RX_MED_NAME , 'AV' as ENC_TYPE
			FROM indata.PRESCRIBING RX LEFT JOIN indata.ENCOUNTER ENC
					ON RX.ENCOUNTERID = ENC.ENCOUNTERID 
                    WHERE 
                    (  
                 
                    RXNORM_CUI IN (SELECT RXNORM_CUI FROM infolder.RCRT2D_MED_RXNORM)
					)
                    AND ENC.ENC_TYPE = 'AV' 

) MED
		WHERE DIAG_ICD.PATID = MED.PATID 

		AND (RX_ORDER_DATE BETWEEN  ADMIT_DATE AND  (ADMIT_DATE + 90))
		) DIAG_ICD_MED

;
quit;

proc sql;
SELECT COUNT(DISTINCT PATID) FROM dmlocal.T1712_RCRT2D_COUNT2;
quit;

proc sql;
create table temp1 as
SELECT  PATID, ADMIT_DATE AS ENTRY_DATE format=date9.
		FROM indata.DIAGNOSIS DIAG where
        compress(DX, '.') IN (&CASE_TEMP1_10.)	        
        ;
quit;

proc sql;
create table temp2 as
SELECT  PATID, ADMIT_DATE AS ENTRY_DATE format=date9.
		FROM indata.DIAGNOSIS DIAG
		where compress(DX, '.') IN (&CASE_TEMP2_09.)
;
quit;

proc sql;
create table temp3 as
SELECT  PATID, RESULT_DATE AS ENTRY_DATE format=date9.
		FROM indata.LAB_RESULT_CM 
		 where  (LAB_LOINC IN (&CASE_TEMP3_LOINC.)
                 OR UPPER(RAW_LAB_NAME) LIKE '%BEHCG%' OR UPPER(RAW_LAB_NAME) LIKE '%B-HCG%' OR UPPER(RAW_LAB_NAME) LIKE '%HCG-B%' OR UPPER(RAW_LAB_NAME) LIKE '%BETHCG%'
				)
			    AND (RESULT_NUM > 5)
;
quit;

data temp4;
set temp1 temp2 temp3;
run;

proc sql;
create table temp as
SELECT  peg.PATID,  peg.ENTRY_DATE format=date9.
		FROM temp4 PEG
					join dmlocal.T1712_RCRT2D_COUNT2 C2
					on C2.PATID = PEG.PATID AND 
					(c2.INDEX_DATE BETWEEN 
case
when 
intnx('month',peg.entry_date,0,"s")<> intnx('month',peg.entry_date,0,"e")
then
intnx('month',peg.entry_date,-3,"s")
else
intnx('month',mdy(month(intnx('month',peg.entry_date,-3,"s")),day(intnx('month',peg.entry_date,-3,"s")),year(intnx('month',peg.entry_date,-3,"s"))),0,"e")
end 
AND 
case
when 
intnx('month',peg.entry_date,0,"s")<> intnx('month',peg.entry_date,0,"e")
then
intnx('month',peg.entry_date,9,"s")
else
intnx('month',mdy(month(intnx('month',peg.entry_date,9,"s")),day(intnx('month',peg.entry_date,9,"s")),year(intnx('month',peg.entry_date,9,"s"))),0,"e")
end 
)
;
quit;

proc sql;
CREATE TABLE dmlocal.T1712_RCRT2D_COUNT3 AS 
SELECT *
FROM
dmlocal.T1712_RCRT2D_COUNT2
WHERE PATID NOT IN(
	select patid from temp)
	AND PATID NOT IN
		(SELECT DISTINCT PATID FROM indata.DIAGNOSIS DIAG
			WHERE (DX_TYPE = '10' AND compress(DX, '.') IN (&CASE_EXC_10.))
			OR
			(DX_TYPE = '09' AND compress(DX, '.') IN (&CASE_EXC_09.)))
         ;
quit;

proc sql;
SELECT COUNT(DISTINCT PATID) FROM dmlocal.T1712_RCRT2D_COUNT3;
quit;

proc datasets library=work nolist; delete temp:; quit;

proc sql;
create table dmlocal.temp1 as
SELECT
	 DISTINCT C3_1Y.*
FROM
	(SELECT DISTINCT C3.* 
	FROM 
	dmlocal.T1712_RCRT2D_COUNT3 C3
	LEFT JOIN indata.ENCOUNTER ENC
	ON C3.PATID = ENC.PATID WHERE ENC.ENC_TYPE IN ('AV', 'IP','EI') AND
admit_DATE BETWEEN 
case
when 
intnx('month',c3.index_date,0,"s")<> intnx('month',c3.index_date,0,"e")
then
intnx('month',c3.index_date,-12,"s")
else
intnx('month',mdy(month(intnx('month',c3.index_date,-12,"s")),day(intnx('month',c3.index_date,-12,"s")),year(intnx('month',c3.index_date,-12,"s"))),0,"e")
end 
AND 
case
when 
intnx('month',c3.index_date-1,0,"s")<> intnx('month',c3.index_date-1,0,"e")
then
intnx('month',c3.index_date-1,-0,"s")
else
intnx('month',mdy(month(intnx('month',c3.index_date-1,-0,"s")),day(intnx('month',c3.index_date-1,-0,"s")),year(intnx('month',c3.index_date-1,-0,"s"))),0,"e")
end 
    ) C3_1Y
	LEFT JOIN indata.ENCOUNTER ENC
	ON C3_1Y.PATID = ENC.PATID
WHERE ENC.ENC_TYPE IN ('AV', 'IP','EI') AND
(		
admit_DATE BETWEEN 
case
when 
intnx('month',c3_1y.index_date,0,"s")<> intnx('month',c3_1y.index_date,0,"e")
then
intnx('month',c3_1y.index_date,-24,"s")
else
intnx('month',mdy(month(intnx('month',c3_1y.index_date,-24,"s")),day(intnx('month',c3_1y.index_date,-24,"s")),year(intnx('month',c3_1y.index_date,-24,"s"))),0,"e")
end 
AND 
case
when 
intnx('month',c3_1y.index_date-1,0,"s")<> intnx('month',c3_1y.index_date-1,0,"e")
then
intnx('month',c3_1y.index_date-1,-12,"s")
else
intnx('month',mdy(month(intnx('month',c3_1y.index_date-1,-12,"s")),day(intnx('month',c3_1y.index_date-1,-12,"s")),year(intnx('month',c3_1y.index_date-1,-12,"s"))),0,"e")
end 
)
;
quit;

/*Testing Temp1*/
Data temp1;
set dmlocal.temp1;
run;

proc sort data=temp1;
by patid index_date;
run;

proc sort data=temp1 nodupkey;
by patid;
run;

proc sql;
CREATE TABLE dmlocal.T1712_RCRT2D_COUNT4 AS 
 SELECT PATID, INDEX_DATE format=date9., ENCOUNTERID, ENC_TYPE, MEDICATION, ICD_CODE
 FROM temp1;
quit;

proc sql;
SELECT COUNT(DISTINCT PATID) FROM dmlocal.T1712_RCRT2D_COUNT4;
quit;

/* CASE 2: */

proc sql;
CREATE TABLE dmlocal.T1712_RCRT2D_COUNT5 AS 
(SELECT PATID, INDEX_DATE format=date9., ENCOUNTERID, ENC_TYPE, DX AS ICD_CODE, LAB_VALUE
FROM
		(SELECT 
				DIAG_ICD.PATID
				, CASE WHEN ADMIT_DATE > RESULT_DATE THEN RESULT_DATE 
					ELSE ADMIT_DATE END AS INDEX_DATE
				, DIAG_ICD.ENCOUNTERID, ENC_TYPE
				, DIAG_ICD.DX
				, LAB.RESULT_NUM as LAB_VALUE					
		FROM
			(
			SELECT DISTINCT DIAG.PATID,  ADMIT_DATE , ENCOUNTERID, ENC_TYPE
			                , DX
			FROM 
				indata.DIAGNOSIS DIAG
			WHERE DIAG.PATID IN (SELECT PATID FROM dmlocal.T1712_RCRT2D_COUNT1) AND  DIAG.PATID NOT IN (SELECT PATID FROM dmlocal.T1712_RCRT2D_COUNT4)
				AND ((DX_TYPE= '09' AND compress(DX, '.') IN (&CASE_ICD_09.))
				 OR
				(DX_TYPE= '10' AND compress(DX, '.') IN (&CASE_ICD_10.)))
				AND ENC_TYPE IN ('AV','IP','EI')
				AND ADMIT_DATE BETWEEN &query_from AND &query_to
				
				) 
				DIAG_ICD
			
			,indata.LAB_RESULT_CM AS LAB
		WHERE DIAG_ICD.PATID = LAB.PATID 
				AND (LAB.RESULT_DATE BETWEEN  (DIAG_ICD.ADMIT_DATE - 90) AND  (DIAG_ICD.ADMIT_DATE + 90))
		
				AND (LAB.LAB_LOINC IN (&CASE_ICD_LOINC_LOINC.)
                     OR UPPER(LAB.RAW_LAB_NAME) LIKE '%A1C%'
                    )
                AND LAB.RESULT_NUM > 6.5 
			
			
		) DIAG_ICD_LAB
	) 
;
quit;

proc sql;
SELECT COUNT(DISTINCT PATID) FROM dmlocal.T1712_RCRT2D_COUNT5;
quit;

proc sql;
drop table temp1;
quit;

proc sql;
create table temp1 as
SELECT  PATID, ADMIT_DATE AS ENTRY_DATE format=date9.
		FROM indata.DIAGNOSIS DIAG 
        WHERE compress(DX, '.') IN (&CASE_TEMP1_10.)	
;
quit;

proc sql;
create table temp2 as
SELECT  PATID, ADMIT_DATE AS ENTRY_DATE format=date9.
		FROM indata.DIAGNOSIS DIAG
		WHERE compress(DX, '.') IN (&CASE_TEMP2_09.)
;
quit;	

proc sql;
create table temp3 as
SELECT  PATID, RESULT_DATE AS ENTRY_DATE format=date9.
		FROM indata.LAB_RESULT_CM 
		 where  (LAB_LOINC in (&CASE_TEMP3_LOINC.) 
                 OR UPPER(RAW_LAB_NAME) LIKE '%BEHCG%' OR UPPER(RAW_LAB_NAME) LIKE '%B-HCG%' OR UPPER(RAW_LAB_NAME) LIKE '%HCG-B%' OR UPPER(RAW_LAB_NAME) LIKE '%BETHCG%'
                )
			    AND (RESULT_NUM > 5)
;
quit;

data temp4;
set temp1 temp2 temp3;
run;

proc sql;
create table temp as
SELECT  peg.PATID,  peg.ENTRY_DATE format=date9.
		FROM temp4 PEG
					join dmlocal.T1712_RCRT2D_COUNT5 C5
					on C5.PATID = PEG.PATID AND 
	(c5.INDEX_DATE BETWEEN 
case
when 
intnx('month',peg.entry_date,0,"s")<> intnx('month',peg.entry_date,0,"e")
then
intnx('month',peg.entry_date,-3,"s")
else
intnx('month',mdy(month(intnx('month',peg.entry_date,-3,"s")),day(intnx('month',peg.entry_date,-3,"s")),year(intnx('month',peg.entry_date,-3,"s"))),0,"e")
end 
AND 
case
when 
intnx('month',peg.entry_date,0,"s")<> intnx('month',peg.entry_date,0,"e")
then
intnx('month',peg.entry_date,9,"s")
else
intnx('month',mdy(month(intnx('month',peg.entry_date,9,"s")),day(intnx('month',peg.entry_date,9,"s")),year(intnx('month',peg.entry_date,9,"s"))),0,"e")
end 
)
;
quit;

proc sql;
CREATE TABLE dmlocal.T1712_RCRT2D_COUNT6 AS 
SELECT *
FROM
dmlocal.T1712_RCRT2D_COUNT5
WHERE PATID NOT IN(
	select patid from temp)
	AND PATID NOT IN
		(SELECT DISTINCT PATID FROM indata.DIAGNOSIS DIAG
			WHERE (DX_TYPE = '10' AND compress(DX, '.') IN (&CASE_EXC_10.))
			       OR
				  (DX_TYPE = '09' AND compress(DX, '.') IN (&CASE_EXC_09.)))
         ;
quit;

proc sql;
SELECT COUNT(DISTINCT PATID) FROM dmlocal.T1712_RCRT2D_COUNT6;
quit;

proc datasets library=work nolist; delete temp:; quit;

proc sql;
create table temp1 as
SELECT
	 DISTINCT C6_1Y.*
FROM
	(SELECT DISTINCT C6.* 
	FROM 
	dmlocal.T1712_RCRT2D_COUNT6 C6
	LEFT JOIN indata.ENCOUNTER ENC
	ON C6.PATID = ENC.PATID WHERE ENC.ENC_TYPE IN ('AV', 'IP','EI') AND
(
admit_DATE BETWEEN 
case
when 
intnx('month',c6.index_date,0,"s")<> intnx('month',c6.index_date,0,"e")
then
intnx('month',c6.index_date,-12,"s")
else
intnx('month',mdy(month(intnx('month',c6.index_date,-12,"s")),day(intnx('month',c6.index_date,-12,"s")),year(intnx('month',c6.index_date,-12,"s"))),0,"e")
end 
AND 
case
when 
intnx('month',c6.index_date-1,0,"s")<> intnx('month',c6.index_date-1,0,"e")
then
intnx('month',c6.index_date-1,-0,"s")
else
intnx('month',mdy(month(intnx('month',c6.index_date-1,-0,"s")),day(intnx('month',c6.index_date-1,-0,"s")),year(intnx('month',c6.index_date-1,-0,"s"))),0,"e")
end 
)
) C6_1Y
	LEFT JOIN indata.ENCOUNTER ENC
	ON C6_1Y.PATID = ENC.PATID
WHERE ENC.ENC_TYPE IN ('AV', 'IP','EI') AND

(
admit_DATE BETWEEN 
case
when 
intnx('month',c6_1y.index_date,0,"s")<> intnx('month',c6_1y.index_date,0,"e")
then
intnx('month',c6_1y.index_date,-24,"s")
else
intnx('month',mdy(month(intnx('month',c6_1y.index_date,-24,"s")),day(intnx('month',c6_1y.index_date,-24,"s")),year(intnx('month',c6_1y.index_date,-24,"s"))),0,"e")
end 
AND 
case
when 
intnx('month',c6_1y.index_date-1,0,"s")<> intnx('month',c6_1y.index_date-1,0,"e")
then
intnx('month',c6_1y.index_date-1,-12,"s")
else
intnx('month',mdy(month(intnx('month',c6_1y.index_date-1,-12,"s")),day(intnx('month',c6_1y.index_date-1,-12,"s")),year(intnx('month',c6_1y.index_date-1,-12,"s"))),0,"e")
end 
)
;
quit;

proc sort data=temp1;
by patid index_date;
run;

proc sort data=temp1 nodupkey;
by patid;
run;

proc sql;
CREATE TABLE dmlocal.T1712_RCRT2D_COUNT7 AS 
 SELECT PATID, INDEX_DATE format=date9., ENCOUNTERID, ENC_TYPE
 , ICD_CODE, LAB_VALUE
 FROM temp1;
quit;

proc sql;
SELECT COUNT(DISTINCT PATID) FROM dmlocal.T1712_RCRT2D_COUNT7;
quit;

/* CASE: 3 */

proc sql;
CREATE TABLE dmlocal.T1712_RCRT2D_COUNT8 AS 

SELECT DISTINCT MED.PATID
	 		
	 			, CASE WHEN LAB_DATE > ORDER_DATE THEN ORDER_DATE ELSE LAB_DATE END as INDEX_DATE format=date9.
				 , MED.ENCOUNTERID
				 , MEDICATION
				 , LAB_VALUE
			FROM
				(SELECT DISTINCT RX.PATID, RX.RX_ORDER_DATE as ORDER_DATE format=date9., RX.ENCOUNTERID
				                								,RX.RAW_RX_MED_NAME AS MEDICATION
					FROM indata.PRESCRIBING RX LEFT JOIN indata.ENCOUNTER ENC
					ON RX.ENCOUNTERID = ENC.ENCOUNTERID 
					WHERE RX.PATID IN (SELECT PATID FROM dmlocal.T1712_RCRT2D_COUNT1) 
						   	AND RX.PATID NOT IN (SELECT PATID FROM dmlocal.T1712_RCRT2D_COUNT4) 
						  	AND RX.PATID NOT IN(SELECT PATID FROM dmlocal.T1712_RCRT2D_COUNT7) 
						    AND 
                            (
                            RXNORM_CUI IN (SELECT RXNORM_CUI FROM infolder.RCRT2D_MED_RXNORM)
                            ) 
                            AND ENC.ENC_TYPE ='AV' 
							AND (RX_ORDER_DATE BETWEEN &query_from AND &query_to)
				   ) MED
				 ,(SELECT PATID, RESULT_DATE as LAB_DATE format=date9.
  							, RESULT_NUM AS LAB_VALUE
                    FROM indata.LAB_RESULT_CM
					WHERE (LAB_LOINC IN (&CASE_ICD_LOINC_LOINC.)
                           OR UPPER(RAW_LAB_NAME)  LIKE '%A1C%'
					      )
                     AND RESULT_NUM > 6.5 					
					)LAB
			WHERE 
				MED.PATID = LAB.PATID
				AND LAB_DATE BETWEEN (ORDER_DATE - 90) AND (ORDER_DATE + 90)
;
quit;

proc sql;
SELECT COUNT(DISTINCT PATID) FROM dmlocal.T1712_RCRT2D_COUNT8;
quit;

proc sql;
drop table temp1;
quit;

proc sql;
create table temp1 as
SELECT  PATID, ADMIT_DATE AS ENTRY_DATE format=date9.
		FROM indata.DIAGNOSIS DIAG where
         compress(DX, '.') IN (&CASE_TEMP1_10.)		        
        ;
quit;

proc sql;
create table temp2 as
SELECT  PATID, ADMIT_DATE AS ENTRY_DATE format=date9.
		FROM indata.DIAGNOSIS DIAG 
		where compress(DX, '.') IN (&CASE_TEMP2_09.)
;
quit;	

proc sql;
create table temp3 as
SELECT  PATID, RESULT_DATE AS ENTRY_DATE format=date9.
		FROM indata.LAB_RESULT_CM 
		 where  ( LAB_LOINC IN (&CASE_TEMP3_LOINC.)
                  OR UPPER(RAW_LAB_NAME) LIKE '%BEHCG%' OR UPPER(RAW_LAB_NAME) LIKE '%B-HCG%' OR UPPER(RAW_LAB_NAME) LIKE '%HCG-B%' OR UPPER(RAW_LAB_NAME) LIKE '%BETHCG%'
                )
			    AND (RESULT_NUM > 5)
;
quit;

data temp4;
set temp1 temp2 temp3;
run;

proc sql;
create table temp as
SELECT  peg.PATID,  peg.ENTRY_DATE format=date9.
		FROM temp4 PEG
					join dmlocal.T1712_RCRT2D_COUNT8 C8
					on C8.PATID = PEG.PATID AND 
	(c8.INDEX_DATE BETWEEN 
case
when 
intnx('month',peg.entry_date,0,"s")<> intnx('month',peg.entry_date,0,"e")
then
intnx('month',peg.entry_date,-3,"s")
else
intnx('month',mdy(month(intnx('month',peg.entry_date,-3,"s")),day(intnx('month',peg.entry_date,-3,"s")),year(intnx('month',peg.entry_date,-3,"s"))),0,"e")
end 
AND 
case
when 
intnx('month',peg.entry_date,0,"s")<> intnx('month',peg.entry_date,0,"e")
then
intnx('month',peg.entry_date,9,"s")
else
intnx('month',mdy(month(intnx('month',peg.entry_date,9,"s")),day(intnx('month',peg.entry_date,9,"s")),year(intnx('month',peg.entry_date,9,"s"))),0,"e")
end 
)
;
quit;

proc sql;
CREATE TABLE dmlocal.T1712_RCRT2D_COUNT9 AS 
SELECT *
FROM
dmlocal.T1712_RCRT2D_COUNT8
WHERE PATID NOT IN(
	select patid from temp)
	AND PATID NOT IN
		(SELECT DISTINCT PATID FROM indata.DIAGNOSIS DIAG
			WHERE (DX_TYPE = '10' AND compress(DX, '.') in (&CASE_EXC_10.))
			       OR
				 (DX_TYPE = '09' AND compress(DX, '.') IN (&CASE_EXC_09.)))
         ;
quit;

proc sql;
SELECT COUNT(DISTINCT PATID) FROM dmlocal.T1712_RCRT2D_COUNT9;
quit;

proc datasets library=work nolist; delete temp:; quit;

proc sql;
create table temp1 as
SELECT
	 DISTINCT C9_1Y.*
FROM
	(SELECT DISTINCT C9.* 
	FROM 
	dmlocal.T1712_RCRT2D_COUNT9 C9
	LEFT JOIN indata.ENCOUNTER ENC
	ON C9.PATID = ENC.PATID WHERE ENC.ENC_TYPE IN ('AV', 'IP','EI') AND

(
admit_DATE BETWEEN 
case
when 
intnx('month',c9.index_date,0,"s")<> intnx('month',c9.index_date,0,"e")
then
intnx('month',c9.index_date,-12,"s")
else
intnx('month',mdy(month(intnx('month',c9.index_date,-12,"s")),day(intnx('month',c9.index_date,-12,"s")),year(intnx('month',c9.index_date,-12,"s"))),0,"e")
end 
AND 
case
when 
intnx('month',c9.index_date-1,0,"s")<> intnx('month',c9.index_date-1,0,"e")
then
intnx('month',c9.index_date-1,-0,"s")
else
intnx('month',mdy(month(intnx('month',c9.index_date-1,-0,"s")),day(intnx('month',c9.index_date-1,-0,"s")),year(intnx('month',c9.index_date-1,-0,"s"))),0,"e")
end 
)

) C9_1Y
	LEFT JOIN indata.ENCOUNTER ENC
	ON C9_1Y.PATID = ENC.PATID
WHERE ENC.ENC_TYPE IN ('AV', 'IP','EI') AND
(
admit_DATE BETWEEN 
case
when 
intnx('month',c9_1y.index_date,0,"s")<> intnx('month',c9_1y.index_date,0,"e")
then
intnx('month',c9_1y.index_date,-24,"s")
else
intnx('month',mdy(month(intnx('month',c9_1y.index_date,-24,"s")),day(intnx('month',c9_1y.index_date,-24,"s")),year(intnx('month',c9_1y.index_date,-24,"s"))),0,"e")
end 
AND 
case
when 
intnx('month',c9_1y.index_date-1,0,"s")<> intnx('month',c9_1y.index_date-1,0,"e")
then
intnx('month',c9_1y.index_date-1,-12,"s")
else
intnx('month',mdy(month(intnx('month',c9_1y.index_date-1,-12,"s")),day(intnx('month',c9_1y.index_date-1,-12,"s")),year(intnx('month',c9_1y.index_date-1,-12,"s"))),0,"e")
end 
)
;
quit;

proc sort data=temp1;
by patid index_date;
run;

proc sort data=temp1 nodupkey;
by patid;
run;

proc sql;
CREATE TABLE dmlocal.T1712_RCRT2D_COUNT10 AS 
 SELECT PATID, INDEX_DATE format=date9., ENCOUNTERID ,'AV' as ENC_TYPE
 		, MEDICATION, LAB_VALUE
 FROM temp1;
quit;

proc sql;
SELECT COUNT(DISTINCT PATID) FROM dmlocal.T1712_RCRT2D_COUNT10;
quit;


proc sql;
create table dmlocal.T1712_RCRT2D_COUNT as
SELECT 'COUNT01' as COUNTS_NAME, COUNT(DISTINCT PATID) as counts,'     ' as CASE_TYPE FROM dmlocal.T1712_RCRT2D_COUNT1 UNION
SELECT 'COUNT02' as COUNTS_NAME, COUNT(DISTINCT PATID) as counts,'CASE1' as CASE_TYPE FROM dmlocal.T1712_RCRT2D_COUNT2 UNION
SELECT 'COUNT03' as COUNTS_NAME, COUNT(DISTINCT PATID) as counts,'CASE1' as CASE_TYPE FROM dmlocal.T1712_RCRT2D_COUNT3 UNION
SELECT 'COUNT04' as COUNTS_NAME, COUNT(DISTINCT PATID) as counts,'CASE1' as CASE_TYPE FROM dmlocal.T1712_RCRT2D_COUNT4 UNION
SELECT 'COUNT05' as COUNTS_NAME, COUNT(DISTINCT PATID) as counts,'CASE2' as CASE_TYPE FROM dmlocal.T1712_RCRT2D_COUNT5 UNION
SELECT 'COUNT06' as COUNTS_NAME, COUNT(DISTINCT PATID) as counts,'CASE2' as CASE_TYPE FROM dmlocal.T1712_RCRT2D_COUNT6 UNION
SELECT 'COUNT07' as COUNTS_NAME, COUNT(DISTINCT PATID) as counts,'CASE2' as CASE_TYPE FROM dmlocal.T1712_RCRT2D_COUNT7 UNION
SELECT 'COUNT08' as COUNTS_NAME, COUNT(DISTINCT PATID) as counts,'CASE3' as CASE_TYPE FROM dmlocal.T1712_RCRT2D_COUNT8 UNION
SELECT 'COUNT09' as COUNTS_NAME, COUNT(DISTINCT PATID) as counts,'CASE3' as CASE_TYPE FROM dmlocal.T1712_RCRT2D_COUNT9 UNION
SELECT 'COUNT10' as COUNTS_NAME, COUNT(DISTINCT PATID) as counts,'CASE3' as CASE_TYPE FROM dmlocal.T1712_RCRT2D_COUNT10
ORDER BY COUNTS_NAME
;
quit;

data dmlocal.count4;
set dmlocal.T1712_RCRT2D_COUNT4;
case_type=1;
run;

PROC SQL;
CREATE TABLE dmlocal.count_4 AS 
 SELECT PATID, ENCOUNTERID, ENC_TYPE, INDEX_DATE, T1 , RXNORM_CUI , MEDICATION, ICD_CODE, CASE_TYPE
 FROM 
(
SELECT RX.PATID, MIN(RX.RX_ORDER_DATE) AS T1 FORMAT=DATE9., RX.RXNORM_CUI, RX.ENCOUNTERID, CNT.INDEX_DATE, CNT.MEDICATION, CNT.ICD_CODE, CNT.ENC_TYPE, CNT.CASE_TYPE
			FROM indata.PRESCRIBING RX  
      INNER JOIN dmlocal.count4 CNT ON RX.PATID = CNT.PATID
      INNER JOIN indata.ENCOUNTER ENC ON RX.ENCOUNTERID = ENC.ENCOUNTERID
         WHERE RXNORM_CUI IN (SELECT RXNORM_CUI FROM infolder.RCRT2D_MED_RXNORM WHERE MED_INCLUSION_FLAG='Y')
         AND RX_ORDER_DATE BETWEEN &query_from AND &query_to
		     AND INDEX_DATE <= RX_ORDER_DATE
		     AND (ENC.ENC_TYPE IN ('AV','OA') )
      GROUP BY RX.PATID  
) ;
QUIT;


data dmlocal.count7;
set dmlocal.T1712_RCRT2D_COUNT7;
case_type=2;
run;

PROC SQL;
CREATE TABLE dmlocal.count_7 AS 
 SELECT PATID, ENCOUNTERID, ENC_TYPE, INDEX_DATE, T1 , RXNORM_CUI , ICD_CODE, LAB_VALUE, CASE_TYPE
 FROM 
(
SELECT RX.PATID, MIN(RX.RX_ORDER_DATE) AS T1 FORMAT=DATE9., RX.RXNORM_CUI, RX.ENCOUNTERID, CNT.INDEX_DATE, CNT.LAB_VALUE, CNT.ICD_CODE, CNT.ENC_TYPE, CNT.CASE_TYPE
			FROM indata.PRESCRIBING RX  
      INNER JOIN dmlocal.count7 CNT ON RX.PATID = CNT.PATID
      INNER JOIN indata.ENCOUNTER ENC ON RX.ENCOUNTERID = ENC.ENCOUNTERID
         WHERE RXNORM_CUI IN (SELECT RXNORM_CUI FROM infolder.RCRT2D_MED_RXNORM WHERE MED_INCLUSION_FLAG='Y')
         AND RX_ORDER_DATE BETWEEN &query_from AND &query_to
		     AND INDEX_DATE <= RX_ORDER_DATE
		     AND (ENC.ENC_TYPE IN ('AV','OA') )
      GROUP BY RX.PATID  
) ;
QUIT;

data dmlocal.count10;
set dmlocal.T1712_RCRT2D_COUNT10;
case_type=3;
run;

PROC SQL;
CREATE TABLE dmlocal.count_10 AS 
 SELECT PATID, ENCOUNTERID, ENC_TYPE, INDEX_DATE, T1 , RXNORM_CUI , MEDICATION, LAB_VALUE, CASE_TYPE
 FROM 
(
SELECT RX.PATID, MIN(RX.RX_ORDER_DATE) AS T1 FORMAT=DATE9., RX.RXNORM_CUI, RX.ENCOUNTERID, CNT.INDEX_DATE, CNT.LAB_VALUE, CNT.MEDICATION, CNT.ENC_TYPE, CNT.CASE_TYPE
			FROM indata.PRESCRIBING RX  
      INNER JOIN dmlocal.count10 CNT ON RX.PATID = CNT.PATID
      INNER JOIN indata.ENCOUNTER ENC ON RX.ENCOUNTERID = ENC.ENCOUNTERID
         WHERE RXNORM_CUI IN (SELECT RXNORM_CUI FROM infolder.RCRT2D_MED_RXNORM WHERE MED_INCLUSION_FLAG='Y')
         AND RX_ORDER_DATE BETWEEN &query_from AND &query_to
		     AND INDEX_DATE <= RX_ORDER_DATE
		     AND (ENC.ENC_TYPE IN ('AV','OA') )
      GROUP BY RX.PATID  
) ;
QUIT;

data dmlocal.count_all;
set dmlocal.count_4 dmlocal.count_7 dmlocal.count_10;
run;

/*
PROC SORT DATA=dmlocal.count_all;
	 BY PATID ENCOUNTERID;
run;

DATA dmlocal.COUNT_X;
	 SET dmlocal.count_all;
	 BY PATID;
RUN;
*/

proc sql;
CREATE TABLE dmlocal.T1712_SELECTED_CASES AS
SELECT PATID, ENCOUNTERID, INDEX_DATE, ENC_TYPE, CASE_TYPE, T1
FROM
dmlocal.count_all
;
quit;

proc sort data=dmlocal.T1712_SELECTED_CASES;
by patid;
run;

proc sort data=dmlocal.T1712_SELECTED_CASES nodupkey;
by patid;
run;

proc sql;
SELECT COUNT(*), ENC_TYPE FROM dmlocal.T1712_RCRT2D_COUNT4 GROUP BY 2;
SELECT COUNT(*), ENC_TYPE FROM dmlocal.T1712_RCRT2D_COUNT7 GROUP BY 2;
SELECT COUNT(*), ENC_TYPE FROM dmlocal.T1712_RCRT2D_COUNT10 GROUP BY 2;
SELECT * FROM dmlocal.T1712_SELECTED_CASES;
quit;

proc sql;
create table dmlocal.CASE_ICD as
SELECT 
			CASES.PATID, DIAG.ADMIT_DATE , CASES.INDEX_DATE
			
		FROM 
			dmlocal.T1712_SELECTED_CASES CASES LEFT JOIN indata.DIAGNOSIS DIAG 
			ON CASES.PATID = DIAG.PATID 
		WHERE DIAG.ADMIT_DATE BETWEEN (CASES.INDEX_DATE - 365) AND (CASES.INDEX_DATE -1)
		AND ((DX_TYPE= '09' AND compress(DX, '.') IN (&CASE_ICD_09.))
				 OR
				(DX_TYPE= '10' AND compress(DX, '.') IN (&CASE_ICD_10.)))
		AND DIAG.ENC_TYPE IN ('AV','IP','EI')
;
quit;


proc sql;
create table dmlocal.CASE_RX as
SELECT RX2.PATID, RX2.RX_ORDER_DATE,INDEX_DATE 
				FROM dmlocal.T1712_SELECTED_CASES CASES 
					LEFT JOIN (SELECT RX.PATID, RX_ORDER_DATE
								FROM indata.PRESCRIBING RX LEFT JOIN indata.ENCOUNTER ENC
										ON RX.ENCOUNTERID = ENC.ENCOUNTERID 
										WHERE 
                                        (
                                         RXNORM_CUI IN (SELECT RXNORM_CUI FROM infolder.RCRT2D_MED_RXNORM)
                                        )  
                                        AND ENC.ENC_TYPE ='AV' 

										AND RX.PATID IN (SELECT PATID FROM dmlocal.T1712_SELECTED_CASES)
										)  RX2
					ON CASES.PATID = RX2.PATID 
				WHERE RX2.RX_ORDER_DATE BETWEEN (CASES.INDEX_DATE - 365) AND (CASES.INDEX_DATE -1)
;
quit;

proc datasets library=work nolist; delete temp:; quit;

proc sql;
create table temp1 as
SELECT DISTINCT CASE_ICD.PATID 
FROM dmlocal.case_icd, dmlocal.case_rx 
WHERE CASE_RX.PATID = CASE_ICD.PATID 
		AND CASE_RX.RX_ORDER_DATE BETWEEN (CASE_ICD.ADMIT_DATE) AND (CASE_ICD.ADMIT_DATE + 90) 
;
quit;

proc sql;
create table dmlocal.CASE_LAB as
SELECT LAB.PATID, LAB.RESULT_DATE
 ,INDEX_DATE 
			FROM dmlocal.T1712_SELECTED_CASES CASES 	
				LEFT JOIN
				indata.LAB_RESULT_CM AS LAB
				ON CASES.PATID = LAB.PATID 
				WHERE (LAB.RESULT_DATE BETWEEN (CASES.INDEX_DATE - 365) AND (CASES.INDEX_DATE -1))
					AND (LAB_LOINC IN (&CASE_ICD_LOINC_LOINC.)
						OR UPPER(LAB.RAW_LAB_NAME) LIKE '%A1C%'
						)
                    AND LAB.RESULT_NUM > 6.5 
;
quit;

proc sql;
create table temp2 as
SELECT DISTINCT CASE_ICD.PATID
from dmlocal.case_icd, dmlocal.CASE_LAB
WHERE CASE_LAB.RESULT_DATE BETWEEN (CASE_ICD.ADMIT_DATE - 90) AND (CASE_ICD.ADMIT_DATE + 90 ) 
		AND CASE_LAB.PATID = CASE_ICD.PATID
;
quit;

proc sql;
create table temp3 as
SELECT DISTINCT CASE_RX.PATID
		FROM dmlocal.case_rx, dmlocal.CASE_LAB
WHERE CASE_LAB.RESULT_DATE BETWEEN (CASE_RX.RX_ORDER_DATE - 90) AND (CASE_RX.RX_ORDER_DATE + 90 ) 
		AND CASE_LAB.PATID = CASE_RX.PATID
;
quit;

data temp;
set temp1 temp2 temp3;
run;

/* drop case_rx case_lab case_icd tables */
proc datasets library=dmlocal nolist; delete case_rx case_lab case_icd; quit; 

proc sql;
CREATE TABLE dmlocal.T1712_SELECTED_CASES_DEMO AS
SELECT CAS.PATID, DEMO.SEX, DEMO.BIRTH_DATE as DOB, CAS.CASE_TYPE, CAS.T1,
 CASE WHEN CAS.PATID IN 
      (select distinct patid from temp)
      THEN 0 
      ELSE 1 
 END as INCIDENT_DM_FLAG
FROM dmlocal.T1712_SELECTED_CASES CAS LEFT JOIN indata.DEMOGRAPHIC DEMO ON CAS.PATID = DEMO.PATID
;
quit;

proc sql;
CREATE TABLE dmlocal.T1712_SELECTED_CASES_DEMO_ENC AS
select a.*, b.SEX, b.DOB, b.INCIDENT_DM_FLAG from dmlocal.t1712_selected_cases a left join dmlocal.t1712_selected_cases_demo b
on a.patid=b.patid;
quit;

proc export data=dmlocal.T1712_SELECTED_CASES_DEMO_ENC
   outfile="&qpath/dmlocal/&DMID._&PACKAGENAME._&VER._SELECTED_CASES_DEMO_ENC.csv"
   dbms=csv
   replace;
run;

data dmlocal.T1712_rcrt2d_count;
set dmlocal.T1712_rcrt2d_count;
if counts=. then counts=0;
if 1<=counts< &threshold then counts=.T;
if COUNTS_NAME='COUNT01' then COUNTS_LABEL='Starting Population                                                      ';
if COUNTS_NAME='COUNT02' then COUNTS_LABEL='Case Type 1 Diabetes ICD codes and Meds                                  ';
if COUNTS_NAME='COUNT03' then COUNTS_LABEL='Case Type 1 with exclusions applied                                      ';
if COUNTS_NAME='COUNT04' then COUNTS_LABEL='Case Type 1 with Encounter Criteria Applied (final count for Case Type 1)';
if COUNTS_NAME='COUNT05' then COUNTS_LABEL='Case Type 2 Diabetes ICD codes and Lab value                             ';
if COUNTS_NAME='COUNT06' then COUNTS_LABEL='Case Type 2 with exclusions applied                                      ';
if COUNTS_NAME='COUNT07' then COUNTS_LABEL='Case Type 2 with Encounter Criteria Applied (final count for Case Type 2)';
if COUNTS_NAME='COUNT08' then COUNTS_LABEL='Case Type 3 Meds and Lab value                                           ';
if COUNTS_NAME='COUNT09' then COUNTS_LABEL='Case Type 3 with exclusions applied                                      ';
if COUNTS_NAME='COUNT10' then COUNTS_LABEL='Case Type 3 with Encounter Criteria Applies (final count for Case Type 3)';
if CASE_TYPE='CASE1' then CASE_LABEL='Diabetes ICD codes and Meds     ';
if CASE_TYPE='CASE2' then CASE_LABEL='Diabetes ICD codes and Lab value';
if CASE_TYPE='CASE3' then CASE_LABEL='Meds and Lab value              ';
run;

proc export data=dmlocal.T1712_rcrt2d_count
   outfile="&qpath/dmlocal/&DMID._&PACKAGENAME._&VER._COUNT.csv"
   dbms=csv
   replace;
run;

ODS Listing CLOSE;

proc printto;
run;


