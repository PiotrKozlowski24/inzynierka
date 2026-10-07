clear; clc;
load('simulation_results.mat');   % T1_vals, T2_vals, L2_vals + 8 macierzy (L2 x T2 x T1)

%% ===== Parametry =====
cfg.nBx        = 80;     % liczba binów w osi X (log10(T2/T1))
cfg.nBy        = 40;     % liczba binów w osi Y (L2)
cfg.ratioPct   = 98;     % percentyl |log2(iloraz)| wyznaczający zakres (100 = pełny zakres)
cfg.shareScale = false;  % true = wspólna skala dla wszystkich metryk-ilorazów
cfg.climOS     = 10;     % zakres przeregulowania [p.p.]

%% ===== Metryki =====
metrics = struct( ...
    'title',   {'Czas narastania', 'Przeregulowanie', 'Czas regulacji', 'ITAE'}, ...
    'label',   {'kaskada / jednopunktowa', ...
                'P_{kaskada} - P_{jednopunktowa} [p.p.]', ...
                'kaskada / jednopunktowa', ...
                'kaskada / jednopunktowa'}, ...
    'isRatio', {true, false, true, true}, ...
    'data',    {riseTime_c(:)     ./ riseTime(:), ...
                overshoot_c(:)    -  overshoot(:), ...
                settlingTime_c(:) ./ settlingTime(:), ...
                ITAE_c(:)         ./ ITAE(:)});

%% ===== Współrzędne punktów i biny (raz, przed pętlą) =====
[L_grid, T2_grid, T1_grid] = ndgrid(L2_vals, T2_vals, T1_vals);

logX = log10(T2_grid(:) ./ T1_grid(:));

% Oś Y = L
Y    = L_grid(:);

% Oś Y = L/T2
% Y    = L_grid(:)./T2_grid(:);

% Oś Y = L/T1
% Y    = L_grid(:)./T1_grid(:);

xe = linspace(min(logX), max(logX), cfg.nBx + 1);
ye = linspace(0, max(Y), cfg.nBy + 1);

ix = discretize(logX, xe);
iy = discretize(Y,    ye);
inBin = ~isnan(ix) & ~isnan(iy);

%% ===== Mediany w binach =====
nM = numel(metrics);
M  = cell(1, nM);
for m = 1:nM
    v = metrics(m).data;
    if metrics(m).isRatio
        v(v <= 0) = NaN;                 % log2 wymaga dodatnich wartości
    end
    ok = isfinite(v) & inBin;
    M{m} = accumarray([iy(ok) ix(ok)], v(ok), [cfg.nBy cfg.nBx], @median, NaN);
end

%% ===== Zakres skali dla ilorazów =====
isR = [metrics.isRatio];
limR = zeros(1, nM);
for m = find(isR)
    limR(m) = symLimit(log2(M{m}), cfg.ratioPct);
end
if cfg.shareScale
    limR(isR) = max(limR(isR));
end

%% ===== Colormap: czerwony -> biały -> niebieski =====
n = 256;
cmap = [linspace(0.85, 1,    n/2)' linspace(0.20, 1,    n/2)' linspace(0.20, 1,    n/2)';
        linspace(1,    0.20, n/2)' linspace(1,    0.45, n/2)' linspace(1,    0.85, n/2)'];

%% ===== Rysunek =====
figure('Color', 'w', 'Position', [100 100 1300 850]);
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

for m = 1:nM
    nexttile;

    if metrics(m).isRatio
        Z    = log2(M{m});               % 1 -> 0 (biały), 2 -> +1, 0.5 -> -1
        lim  = limR(m);
        cb   = drawMap(xe, ye, Z, cmap, [-lim lim]);

        [tk, tl] = ratioTicks(lim);
        cb.Ticks      = tk;
        cb.TickLabels = tl;
    else
        cb = drawMap(xe, ye, M{m}, cmap, [-cfg.climOS cfg.climOS]);
    end

    cb.Label.String = metrics(m).label;
    xlabel('T_2/T_1');
    ylabel('L_2');
    title(metrics(m).title);
    box on;
end

%% ===== Funkcje lokalne =====
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