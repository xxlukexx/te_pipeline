path_out = '/users/luke/desktop/bttmp';
tracker = tepTest_CreateShamEnobioEEGWithLightSensor(path_out, 100, 1, 0.050, 0.100);
ses = teSession(tracker.Path_Session);
ext = ses.ExternalData('enobio');
delete(ext.Paths('enobio_info'))
ft = eegEnobio2Fieldtrip(ext.Paths('enobio_easy'));

cfg = struct;

cfg.trl = [[ft.events.sample]' - 50, [ft.events.sample]' + 750, repmat(-50, length(ft.events), 1)];
data = ft_redefinetrial(cfg, ft);

ft = eegFT_correctFromLightSensor(ft, 1000, 100);
cfg.trl = [[ft.events.sample]' - 50, [ft.events.sample]' + 750, repmat(-50, length(ft.events), 1)];
data_corr = ft_redefinetrial(cfg, ft);

subplot(2, 1, 1)
ft_singleplotER([], data);
title('Segmented using markers')
subplot(2, 1, 2)
ft_singleplotER([], data_corr);
title('Segmented using light sensor')