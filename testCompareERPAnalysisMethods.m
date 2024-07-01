ses = teSession('/Volumes/data_braintools/test/BT308/2018-10-02T142756');
res_te = fasterp_analyse(ses);
[res_ft, steps_ft] = fasterp_analyse_ft(ses);

%%

cfg = [];
cfg.layout = 'EEG1010.lay';
ft_multiplotER(cfg, res_te.avg, res_ft.avg)
