accessList = {...
    '10-DD-B1-98-B8-FB'     % luke mbp15 home eth
    'F0-18-98-46-69-0E'     % luke mbp15 home wifi
    'C0-56-27-B1-18-7A'     % luke mbp15 office eth
    '0C-4D-E9-AA-A7-29'     % lm_analysis (imac)
    '98-5A-EB-CB-33-48'     % rianne
    'A0-99-9B-17-3F-AB'     % rianne2 
    'E4-50-EB-B8-31-35'     % bertha
    };
save('/users/luke/desktop/access.mat', 'accessList');
