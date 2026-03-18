function matlab_serial_date = convertTAITime(TAI)
matlab_serial_date = (TAI + 725846400 - 6)/86400 + datenum('1/1//1970');
