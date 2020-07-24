
/*****************************************************************************************************/
/**************************** PLEASE DO NOT EDIT CODE BELOW THIS LINE ********************************/
/*****************************************************************************************************/
%macro define_concepts;

 /*set code list to macro variables by concepts and code type*/
 %set_concepts(part1_case_dx, dxpx);
 %set_concepts(part1_case_loinc, lonic);
 %set_concepts(part2_comorb_dx, dxpx);
 %set_concepts(part2_comorb_px, dxpx);
 %set_concepts(part2_comorb_loinc, lonic);

%mend;

%macro set_concepts(inds, codetype);

 data codes;
  length code_w_str $20;
  set infolder.&inds;
  %if &codetype ne lonic %then %do; 
   code_w_str="'"||strip(code_clean)||"'"; 
  %end;
  %else %do;
   code_w_str="'"||strip(code)||"'"; 
  %end;
 run;

 proc sql noprint;
   create table concepts as select distinct concept, codetype from codes;
 quit;

 data _null_;
   set concepts end=end;
   count+1;
   call symputx('cncept'||put(count,4.-l),concept);
   call symputx('cdtype'||put(count,4.-l),codetype);
   if end then call symputx('n',count);
 run;

 %do i=1 %to &n;
  %let concept = &&cncept&i;
  %let codetype = &&cdtype&i;
  %global &concept._&codetype;
 
  proc sql noprint;
    select code_w_str into :&concept._&codetype. separated by ', '  from codes
    where concept = "&&cncept&i" and codetype="&&cdtype&i";
  quit;

 %end;
 %mend;
%define_concepts;


