#!/bin/csh

# Modified by Jamie Moker Feb 2018

# usage:
# csh 01_setup_WPS_longbdy_v06.csh yyyy mm dd hh

if ( "$4" == "" ) then
    echo " "
    echo "Uh oh!"
    echo "Too few arguments. Need to include date of initialization"
    echo "in the format yyyy mm dd hh separated by spaces."
    echo "For instance: csh 01_setup_WPS_longbdy_v06.csh 2013 07 08 00"
    echo " "
    exit 0
endif

cd /st1/jmoker

set initial_date = ${1}${2}${3}${4}
set CASE_NAME = ${1}_${2}_${3}

set RUN_DIR = /st1/jmoker/DART_IC
set CASE_DIR = /st1/jmoker/DART_IC/${CASE_NAME}
set LBC_DIR =  /no2/jmoker/LBC

set RAP_DIR = ${CASE_DIR}/ungrib_RAP
set GFS_DIR = ${CASE_DIR}/ungrib_GFS

set spinup_time = 6
set assim_time = 6 
set forecast_time = 24 # hours
set spinup_and_assim_time = `expr ${spinup_time} + ${assim_time}`
set total_time = `expr ${spinup_time} + ${assim_time} + ${forecast_time}`

set date_init  =  `echo ${initial_date} 0h -w | ${RUN_DIR}/run/advance_time`
set yyyy_init   = ${1}
set mm_init     = ${2}
set dd_init     = ${3}
set hh_init     = ${4}

set date_start  =  `echo ${initial_date} ${spinup_and_assim_time}h -w | ${RUN_DIR}/run/advance_time`
set yyyy_start   = `echo ${initial_date} ${spinup_and_assim_time}h | ${RUN_DIR}/run/advance_time | cut -b1-4`
set mm_start    = `echo ${initial_date} ${spinup_and_assim_time}h | ${RUN_DIR}/run/advance_time | cut -b5-6`
set dd_start    = `echo ${initial_date} ${spinup_and_assim_time}h | ${RUN_DIR}/run/advance_time | cut -b7-8`
set hh_start     = `echo ${initial_date} ${spinup_and_assim_time}h | ${RUN_DIR}/run/advance_time | cut -b9-10`

set date_end  =  `echo ${initial_date} ${total_time}h -w | ${RUN_DIR}/run/advance_time`
set yyyy_end     = `echo ${initial_date} ${total_time}h  | ${RUN_DIR}/run/advance_time | cut -b1-4`
set mm_end      = `echo ${initial_date} ${total_time}h | ${RUN_DIR}/run/advance_time | cut -b5-6`
set dd_end      = `echo ${initial_date} ${total_time}h | ${RUN_DIR}/run/advance_time | cut -b7-8`
set hh_end       = `echo ${initial_date} ${total_time}h | ${RUN_DIR}/run/advance_time | cut -b9-10`

#echo ${CASE_DIR}
#echo ${date_init} ${yyyy_init} ${mm_init} ${dd_init} ${hh_init}
#echo ${date_start} ${yyyy_start} ${mm_start} ${dd_start} ${hh_start}
#echo ${date_end} ${yyyy_end} ${mm_end} ${dd_end} ${hh_end}
#exit 0


if ( ! -d ${RUN_DIR} ) mkdir -p ${RUN_DIR}

if ( -d ${CASE_DIR} ) rm -rf ${CASE_DIR}
mkdir -p ${CASE_DIR}

if ( -d ${RAP_DIR} ) rm -rf ${RAP_DIR}
mkdir -p ${RAP_DIR}

if ( -d ${GFS_DIR} ) rm -rf ${GFS_DIR}
mkdir -p ${GFS_DIR}


### setup ungrib RAP soil

ln -sf ${RUN_DIR}/run/ungrib.exe ${RAP_DIR}/.
ln -sf ${RUN_DIR}/run/Vtable.RAP_soil ${RAP_DIR}/Vtable
ln -sf ${RUN_DIR}/run/link_grib.csh ${RAP_DIR}/.
cp ${RUN_DIR}/templates/namelist_RAP.wps ${RAP_DIR}/namelist.wps
sed -i "4s/.*/ start_date = '${date_init}','${date_init}','${date_init}',/" ${RAP_DIR}/namelist.wps
sed -i "5s/.*/ end_date = '${date_init}'','${date_init}','${date_init}',/" ${RAP_DIR}/namelist.wps

### setup ungrib GFS

ln -sf ${RUN_DIR}/run/ungrib.exe ${GFS_DIR}/.
ln -sf ${RUN_DIR}/run/Vtable.GFS_no_soil ${GFS_DIR}/Vtable
ln -sf ${RUN_DIR}/run/link_grib.csh ${GFS_DIR}/.
cp ${RUN_DIR}/templates/namelist_GFS.wps ${GFS_DIR}/namelist.wps
sed -i "4s/.*/ start_date = '${date_init}','${date_init}','${date_init}',/" ${GFS_DIR}/namelist.wps
sed -i "5s/.*/ end_date = '${date_end}','${date_end}','${date_end}',/" ${GFS_DIR}/namelist.wps


set yr = `echo $1 | cut -b3-4`

# link LBC from initializations during spinup and DA time
set n = 1
@ nx = ( ${spinup_and_assim_time} / 6  )  
while ( ${n} <= ${nx} )
  @ nh = ($n - 1) * 6
  set mm0    = `echo ${initial_date} ${nh}h | ${RUN_DIR}/run/advance_time | cut -b5-6`
  set dd0    = `echo ${initial_date} ${nh}h  | ${RUN_DIR}/run/advance_time | cut -b7-8`
  set hh0     = `echo ${initial_date} ${nh}h  | ${RUN_DIR}/run/advance_time | cut -b9-10`
  ln -sf ${LBC_DIR}/gfs/${yr}${mm0}${dd0}_t${hh0}z_f00.grib2 ${GFS_DIR}/.
  @ n++
end

# link LBC from forecasts during forecast time
set n = 1
@ nx = ( (${total_time} - ${spinup_and_assim_time}) / 6 + 1 )
while ( ${n} <= ${nx} )
  @ nh = ($n - 1) * 6
  set nhf = `printf "%02d" $nh`
  ln -sf ${LBC_DIR}/gfs/${yr}${mm_start}${dd_start}_t${hh_start}z_f${nhf}.grib2 ${GFS_DIR}/.
  @ n++
end

#Ungrib RAP
cd ${RAP_DIR}
./link_grib.csh ${LBC_DIR}/rap/${yr}${mm_init}${dd_init}_t${hh_init}z_f00*
./ungrib.exe

#Ungrib GFS
cd ${GFS_DIR}
./link_grib.csh *grib2
./ungrib.exe

cd ${CASE_DIR}

# Run Metgrid.exe

ln -sf ${RUN_DIR}/geo_em_files/* .
ln -sf ${RUN_DIR}/run/metgrid.exe .
ln -sf ${RUN_DIR}/run/METGRID.TBL.AVE METGRID.TBL
cp ${RUN_DIR}/templates/namelist.wps .
sed -i "4s/.*/ start_date = '${date_init}','${date_init}','${date_init}',/"  namelist.wps
sed -i "5s/.*/ end_date = '${date_end}','${date_end}','${date_end}',/" namelist.wps
sed -i "39s/.*/ constants_name = 'RAP_SOIL:${yyyy_init}-${mm_init}-${dd_init}_${hh_init}',/" namelist.wps
ln -sf ${GFS_DIR}/GFS* .
ln -sf ${RAP_DIR}/RAP* .
./metgrid.exe
#mpirun -np 8 metgrid.exe

# Run Real.exe

ln -sf /st1/jmoker/WRF341/WRFV3/main/real.exe .
cp ${RUN_DIR}/templates/namelist.input .
sed -i "7s/.*/ start_month   = ${mm_init},  ${mm_init},  ${mm_init},/" namelist.input
sed -i "8s/.*/  start_day     = ${dd_init}, ${dd_init},  ${dd_init},/" namelist.input
sed -i "9s/.*/  start_hour    = ${hh_init},  ${hh_init},   ${hh_init},/" namelist.input
sed -i "13s/.*/  end_month    = ${mm_end},  ${mm_end},  ${mm_end},/" namelist.input
sed -i "14s/.*/  end_day       = ${dd_end}, ${dd_end},  ${dd_end},/" namelist.input
sed -i "15s/.*/  end_hour      = ${hh_end},  ${hh_end},   ${hh_end},/" namelist.input
mpirun -np 8 real.exe
ln -fs wrfinput_d01 wrfinput_d01.${date_init}

exit 0
