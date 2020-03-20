lm_addCommonPaths
% path_data = '/Volumes/data_arbac/bbk-pilot/test_luke_tmp/0656/2019-06-19T124549';
% path_data = '/Volumes/data_arbac/tests-lm/161000301103/2019-09-19T162753';
path_data = '/Volumes/data_braintools/test/BT301/2018-09-17T150503';

data = teSession(path_data);
[val, sync, reason] = teFT_findSyncOffset2(data, [], '-removeEnobio255');

oddball = oddball_pond_analyse(data, sync);
faceerp = faceerp_analyse(data, sync);
aud_ss = aud_ss_analyse(data, sync);

    % plot
    cfg = [];
    cfg.channel = {'P7', 'P8'};
    ft_singleplotER(cfg, faceerp.avg_fu, faceerp.avg_fi, faceerp.avg_hu)


