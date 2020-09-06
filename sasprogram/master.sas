/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *                                                                     
* Program Name:  master.sas                          
*         Date:  11/16/2018                                               
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
* Purpose:  The purpose of the program is for RCR T2D Cohort Identification and Characteristics 
*           Query analyzes data from PCORnet Common Data Model (CDM) v4.1 compliant tables.
*
*  Inputs:  
*           1) CDM tables:                                                                                                                      
*              demographic                                                            
*              diagnosis                                                                                                        
*              encounter                                                              
*              lab_result_cm                                            
*              procedures                                                             
*              prescribing 
*
*           2) SAS supporting files at /infolder
*              code_reference.cpt 
*
*           3) SAS programs at /infolder/macros
*              master_part1.sas
*              master_part2.sas
*              define_concepts.sas
*                            
*  Output:
*           1) Output files from master_part1 stored in /dmlocal 
*           2) SAS datasets from master_part2 stored in /dmtable
*           3) Files Returned to the DRN OC stored in /dmoutput 
* 
*  Requirement:  
*               1) Program run in SAS 9.3 or higher
*             
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */;
options errorabend validvarname=upcase;

/********** ENTER FOLDER CONTAINING INPUT DATA FILES AND MSCDM DATA ***************************************/;	
%LET indata=/aaa/bbb/;

/********** ENTER ROOT DIRECTORY TO SUB-DIRECTORY FOR THE QUERY PACKAGE  ***************************************/;
%LET qpath=/xxx/yyy/;	

/*****************************************************************************************************/
/**************************** PLEASE DO NOT EDIT CODE BELOW THIS LINE ********************************/
/*****************************************************************************************************/

/* Set query period */
%let query_from= '01jan2004'd;
%let query_to= '31dec2019'd;

/* Set threshold value */
%let THRESHOLD=11;

/********************************************************************************
*- Set LIBNAMES for INPUT FILES AND MSCDM DATA
*******************************************************************************/
libname indata "&indata." access=readonly;
libname infolder "&qpath.infolder/";
/********************************************************************************
*- Set LIBNAME for FINAL DATASETS from PART1 TO BE KEPT LOCAL AT THE PARTNER SITE
*********************************************************************************/
libname dmlocal "&qpath.dmlocal/";
/********************************************************************************
*- Set LIBNAME for FINAL DATASETS from PART2 TO BE KEPT LOCAL AT THE PARTNER SITE 
*********************************************************************************/;
libname dmtable "&qpath.dmtable/";
/********************************************************************************
*- Set LIBNAME for CONTAINING SUMMARY FILES TO BE EXPORTED TO OPERATION CENTER
*********************************************************************************/;
libname dmoutput "&qpath.dmoutput/";
/********************************************************************************
*- Import transport file for all reference data sets
*********************************************************************************/;
filename tranfile "&qpath.infolder/code_reference.cpt";
proc cimport infile=tranfile library=infolder; run;
/********************************************************************************;
*- Create macro variable from DataMart ID 
********************************************************************************/;
data _null_;
     set indata.harvest;
     call symput("DMID",strip(datamartid));
run;
/********************************************************************************
* Submit query programs
********************************************************************************/;
%include "&qpath.infolder/macros/define_concepts.sas";
%include "&qpath.infolder/macros/master_part1.sas";
/* Flush datasets in WORK ENVIRONMENT */
proc datasets nolist nodetails lib=work kill memtype=data; quit;

%include "&qpath.infolder/macros/master_part2.sas";

