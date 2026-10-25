clear; clc;

%% ===== Parametry =====
cfg.baseFile   = 'simulation_results.mat';     % wyniki bez zakłóceń
cfg.distFiles  = {'simulation_results_step_input.mat',  ...
                  'simulation_results_step_middle.mat', ...
                  'simulation_results_step_output.mat', ...
                  'simulation_results_noise_input.mat', ...
                  'simulation_results_noise_middle.mat', ...
                  'simulation_results_noise_output.mat'};
cfg.nBx        = 200;     % liczba binów w osi X (log10(T2/T1))
cfg.nBy        = 40;      % liczba binów w osi Y (L2)
cfg.ratioPct   = 98;      % percentyl |log2(iloraz)| wyznaczający zakres
cfg.shareScale = false;   % true = wspólna skala dla ilorazów w danym zestawie
cfg.climOS     = 10;      % zakres przeregulowania [p.p.]
cfg.export     = false;   % true = zapis PNG (300 dpi) do folderu 'mapy'
cfg.ratioMax   = 5;       % stała skala ilorazów: [1/ratioMax, ratioMax], np. [0.25 4]
                          % [] = skala automatyczna (percentyl, jak dotąd)

%% ===== Dane bazowe i biny (raz, wspólne dla wszystkich zestawów) =====
S = load(cfg.baseFile);

[L_grid, T2_grid, T1_grid] = ndgrid(S.L2_vals, S.T2_vals, S.T1_vals);
logX = log10(T2_grid(:) ./ T1_grid(:));

% Oś Y = L2  (alternatywy: L_grid(:)./T2_grid(:)  lub  L_grid(:)./T1_grid(:))
Y = L_grid(:);

bins.xe = linspace(min(logX), max(logX), cfg.nBx + 1);
bins.ye = linspace(0, max(Y), cfg.nBy + 1);
bins.ix = discretize(logX, bins.xe);
bins.iy = discretize(Y,    bins.ye);
bins.inBin = ~isnan(bins.ix) & ~isnan(bins.iy);

%% ===== Colormap: czerwony -> biały -> niebieski =====
n = 256;
cmap = [linspace(0.85, 1,    n/2)' linspace(0.20, 1,    n/2)' linspace(0.20, 1,    n/2)';
        linspace(1,    0.20, n/2)' linspace(1,    0.45, n/2)' linspace(1,    0.85, n/2)'];

%% ===== Zestaw 1: bez zakłóceń =====
metrics = struct( ...
    'title',   {'Czas narastania', 'Przeregulowanie', 'Czas regulacji', 'ITAE'}, ...
    'label',   {'kaskada / jednopunktowa', ...
                'P_{kaskada} - P_{jednopunktowa} [p.p.]', ...
                'kaskada / jednopunktowa', ...
                'kaskada / jednopunktowa'}, ...
    'isRatio', {true, false, true, true}, ...
    'data',    {S.riseTime_c(:)     ./ S.riseTime(:), ...
                S.overshoot_c(:)    -  S.overshoot(:), ...
                S.settlingTime_c(:) ./ S.settlingTime(:), ...
                S.ITAE_c(:)         ./ S.ITAE(:)});

plotMaps(metrics, bins, cmap, cfg, 'bez_zaklocen');

%% ===== Zestawy 2..N: z zakłóceniami =====
typeNames = struct('step', 'skok', 'noise', 'szum gaussowski');
locNames = struct('input', 'wejście obiektu', ...
                  'middle', 'między G_1 i G_2', ...
                  'output', 'wyjście obiektu');
for f = 1:numel(cfg.distFiles)
    file = cfg.distFiles{f};
    if ~isfile(file)
        warning('Brak pliku %s - pomijam.', file);
        continue;
    end
    D = load(file);
    
        fprintf('\n%s\n', file);
    fprintf('  base ITAE      : %s\n', mat2str(size(S.ITAE)));
    fprintf('  ITAE_d / _d_c  : %s / %s\n', mat2str(size(D.ITAE_d)), mat2str(size(D.ITAE_d_c)));
    fprintf('  IAE_d  / _d_c  : %s / %s\n', mat2str(size(D.IAE_d)),  mat2str(size(D.IAE_d_c)));
    if isfield(D,'T1_vals')
        fprintf('  siatka pliku   : L2=%d, T2=%d, T1=%d\n', ...
            numel(D.L2_vals), numel(D.T2_vals), numel(D.T1_vals));
    end

    desc = sprintf('%s, %s', typeNames.(D.dist.type), locNames.(D.dist.location));
    tag  = sprintf('%s_%s', D.dist.type, D.dist.location);

    % Dla szumu ITAE jest mało miarodajne (szum nie wygasa) - tylko IAE
    if strcmp(D.dist.type, 'noise')
        metrics = struct( ...
            'title',   {['IAE - ' desc]}, ...
            'label',   {'kaskada / jednopunktowa'}, ...
            'isRatio', {true}, ...
            'data',    {D.IAE_d_c(:) ./ D.IAE_d(:)});
    else
        metrics = struct( ...
            'title',   {['ITAE - ' desc], ['IAE - ' desc]}, ...
            'label',   {'kaskada / jednopunktowa', 'kaskada / jednopunktowa'}, ...
            'isRatio', {true, true}, ...
            'data',    {D.ITAE_d_c(:) ./ D.ITAE_d(:), ...
                        D.IAE_d_c(:)  ./ D.IAE_d(:)});
    end

    plotMaps(metrics, bins, cmap, cfg, tag);
end

%% ===== Funkcje lokalne =====
function plotMaps(metrics, bins, cmap, cfg, tag)
    % Liczy mediany w binach i rysuje po jednej figurze na metrykę.
    nM = numel(metrics);
    M  = cell(1, nM);
    for m = 1:nM
        v = metrics(m).data;
        if metrics(m).isRatio
            v(v <= 0) = NaN;             % log2 wymaga dodatnich wartości
        end
        ok = isfinite(v) & bins.inBin;
        M{m} = accumarray([bins.iy(ok) bins.ix(ok)], v(ok), ...
                          [cfg.nBy cfg.nBx], @median, NaN);
    end

    % Zakres skali dla ilorazów
    isR  = [metrics.isRatio];
    limR = zeros(1, nM);
    if ~isempty(cfg.ratioMax)
        limR(isR) = log2(cfg.ratioMax);      % stała skala dla wszystkich map
    else
        for m = find(isR)
            limR(m) = symLimit(log2(M{m}), cfg.ratioPct);
        end
        if cfg.shareScale && any(isR)
            limR(isR) = max(limR(isR));
        end
    end

    if cfg.export && ~isfolder('mapy')
        mkdir('mapy');
    end

    for m = 1:nM
        figure('Color', 'w', ...
               'Position', [100+30*(m-1) 100-30*(m-1) 800 600], ...
               'Name', metrics(m).title, 'NumberTitle', 'off');

        if metrics(m).isRatio
            Z   = log2(M{m});            % 1 -> 0 (biały), 2 -> +1, 0.5 -> -1
            lim = limR(m);
            cb  = drawMap(bins.xe, bins.ye, Z, cmap, [-lim lim]);

            [tk, tl] = ratioTicks(lim);
            cb.Ticks      = tk;
            cb.TickLabels = tl;
        else
            cb = drawMap(bins.xe, bins.ye, M{m}, cmap, [-cfg.climOS cfg.climOS]);
        end

        cb.Label.String = metrics(m).label;
        xlabel('T_2/T_1');
        ylabel('L_2');
        title(metrics(m).title);
        box on;

        if cfg.export
            name = lower(regexprep(metrics(m).title, '[^\w]+', '_'));
            exportgraphics(gcf, fullfile('mapy', sprintf('mapa_%s_%s.png', tag, name)), ...
                           'Resolution', 300);
        end
    end
end

function cb = drawMap(xe, ye, Z, cmap, lims)
    % Rysuje mapę pcolor w osi X logarytmicznej i zwraca colorbar.
    [nBy, nBx] = size(Z);
    h = pcolor(10.^xe, ye, [Z, nan(nBy, 1); nan(1, nBx + 1)]);
    set(h, 'EdgeColor', 'none');
    set(gca, 'XScale', 'log', 'Layer', 'top');
    colormap(gca, cmap);
    clim(lims);
    cb = colorbar;
end

function lim = symLimit(Zlog, pct)
    % Symetryczny zakres wokół 0 z percentyla |Zlog| (odporny na outliery).
    a = abs(Zlog(isfinite(Zlog)));
    if isempty(a)
        lim = 1;
        return;
    end
    lim = prctile(a, pct);
    if lim <= eps
        lim = 1;
    end
end

function [tk, tl] = ratioTicks(lim)
    % Tiki w skali log2, opisane rzeczywistymi wartościami ilorazu.
    k = floor(lim);
    if k >= 1
        tk = -k:k;                       % potęgi 2: ..., 0.5, 1, 2, ...
    else
        tk = linspace(-lim, lim, 5);     % wąski zakres: 5 równych tików
    end
    tl = compose('%.3g', 2.^tk);
end