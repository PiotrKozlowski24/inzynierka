s = tf('s');
T1_vals = linspace(1, 10, 100);
T2_vals = linspace(10, 200, 200);

L2_vals = [0];

nL = length(L2_vals);
nT2 = length(T2_vals);
nT1 = length(T1_vals);

% Preallocate (L2 x T2 x T1)
riseTime     = zeros(nL, nT2, nT1);
overshoot    = zeros(nL, nT2, nT1);
settlingTime = zeros(nL, nT2, nT1);
ITAE         = zeros(nL, nT2, nT1);

riseTime_c     = zeros(nL, nT2, nT1);
overshoot_c    = zeros(nL, nT2, nT1);
settlingTime_c = zeros(nL, nT2, nT1);
ITAE_c         = zeros(nL, nT2, nT1);

%%
t_sim = 0:0.1:2000;

fprintf('Sweeping L2 values...\n');

for k = 1:nL
    L2 = L2_vals(k);
    fprintf('  L2 = %.1f  (%d/%d)\n', L2, k, nL);

    for i = 1:nT2
        for j = 1:nT1

            T1 = T1_vals(j);
            T2 = T2_vals(i);
            % Display the current T1 and T2 values
            fprintf('    T1 = %.1f, T2 = %.1f\n', T1, T2);

            G_s = 1 / (T1*s + 1);
            G_p = tf(1, [T2 1], 'InputDelay', L2);

            % ---- Single-loop PID ----
            G_total = G_s * G_p;
            C = pidtune(G_total, 'PID');
            T_cl = feedback(C * G_total, 1);

            info = stepinfo(T_cl);
            riseTime(k,i,j)     = info.RiseTime;
            overshoot(k,i,j)    = info.Overshoot;
            settlingTime(k,i,j) = info.SettlingTime;

            [y, t] = step(T_cl, t_sim);
            ITAE(k,i,j) = trapz(t, t .* abs(1 - y));

            % ---- Cascade PID ----
            C1 = pidtune(G_s, 'PID');
            T_inner = feedback(C1 * G_s, 1);

            G_outer = T_inner * G_p;
            C2 = pidtune(G_outer, 'PID');
            T_cascade = feedback(C2 * G_outer, 1);

            info_c = stepinfo(T_cascade);
            riseTime_c(k,i,j)     = info_c.RiseTime;
            overshoot_c(k,i,j)    = info_c.Overshoot;
            settlingTime_c(k,i,j) = info_c.SettlingTime;

            [yc, tc] = step(T_cascade, t_sim);
            ITAE_c(k,i,j) = trapz(tc, tc .* abs(1 - yc));
        end
    end
end

%% Save results
save('simulation_results.mat', ...
    'riseTime', 'overshoot', 'settlingTime', 'ITAE', ...
    'riseTime_c', 'overshoot_c', 'settlingTime_c', 'ITAE_c', ...
    'T1_vals', 'T2_vals', 'L2_vals');

fprintf('Results saved to simulation_results.mat\n');


%%

load('simulation_results.mat');

% ---- Plotting ----
metrics = {'Rise Time', 'Overshoot (%)', 'Settling Time', 'ITAE'};
data_single   = {riseTime,   overshoot,   settlingTime,   ITAE};
data_cascade  = {riseTime_c, overshoot_c, settlingTime_c, ITAE_c};

for k = 1:nL
    L2 = L2_vals(k);

    for m = 1:4
        D  = squeeze(data_single{m}(k,:,:));
        Dc = squeeze(data_cascade{m}(k,:,:));
        Dd = D - Dc;   % positive = single-loop worse

        figure('Name', sprintf('L2=%.0f | %s', L2, metrics{m}), ...
               'NumberTitle', 'off');

        % Difference (red = single-loop worse, blue = cascade worse)
        imagesc(T1_vals, T2_vals, Dd);
        set(gca,'YDir','normal');
        cmax = max(abs(Dd(:)));
        if cmax > 0, clim([-cmax cmax]); end
        colormap(gca, redblue(256));
        colorbar;
        title(sprintf('Difference (single − cascade)\nL2 = %.0f', L2));
        xlabel('T1'); ylabel('T2');

        sgtitle(sprintf('%s  |  L2 = %.0f', metrics{m}, L2));
    end
end

% ---- Summary: ITAE difference vs L2 (scalar: mean over T1/T2 space) ----
mean_ITAE_diff = zeros(nL, 1);
for k = 1:nL
    diff_k = squeeze(ITAE(k,:,:)) - squeeze(ITAE_c(k,:,:));
    mean_ITAE_diff(k) = mean(diff_k(:));
end

figure('Name', 'Mean ITAE difference vs L2', 'NumberTitle', 'off');
bar(L2_vals, mean_ITAE_diff);
xlabel('L2 (dead time)');
ylabel('Mean ITAE_{single} − ITAE_{cascade}');
title('Cascade advantage vs dead time (positive = cascade wins)');
grid on;
%% ---- Analysis vs T2/T1 ratio ----

ratio_min = 1;
ratio_max = 200;
nBins = 1000;

ratio_edges = linspace(ratio_min, ratio_max, nBins+1);
ratio_centers = (ratio_edges(1:end-1) + ratio_edges(2:end))/2;

metrics = {'Rise Time', 'Overshoot (%)', 'Settling Time', 'ITAE'};

single_data = {riseTime, overshoot, settlingTime, ITAE};
cascade_data = {riseTime_c, overshoot_c, settlingTime_c, ITAE_c};

for m = 1:length(metrics)

    figure('Name', ['Difference vs T2/T1 Ratio - ' metrics{m}], ...
           'NumberTitle', 'off');

    hold on;
    grid on;

    for k = 1:nL

        % Collect all ratios and differences
        ratios = [];
        diffs  = [];

        for i = 1:nT2
            for j = 1:nT1

                T1 = T1_vals(j);
                T2 = T2_vals(i);

                ratio = T2 / T1;

                if ratio >= ratio_min && ratio <= ratio_max

                    val_single = single_data{m}(k,i,j);
                    val_cascade = cascade_data{m}(k,i,j);

                    diff_val = val_single - val_cascade;

                    ratios(end+1) = ratio;
                    diffs(end+1)  = diff_val;
                end
            end
        end

        % Bin averaging
        mean_diff = nan(1, nBins);

        for b = 1:nBins

            idx = ratios >= ratio_edges(b) & ...
                  ratios <  ratio_edges(b+1);

            if any(idx)
                mean_diff(b) = mean(diffs(idx));
            end
        end

        plot(ratio_centers, mean_diff, 'LineWidth', 2, ...
             'DisplayName', sprintf('L2 = %.1f', L2_vals(k)));
    end

    yline(0, '--k');
    xlim([1, 200]);

    xlabel('T2 / T1');
    ylabel('Mean(single - cascade)');
    title([metrics{m} ' Difference vs T2/T1 Ratio']);

    legend('Location', 'best');
end


%%
% ---- Helper ----
function cmap = redblue(m)
    if nargin < 1, m = 256; end
    bottom = [0 0 1]; middle = [1 1 1]; top = [1 0 0];
    cmap = zeros(m, 3);
    for i = 1:3
        cmap(:,i) = interp1([1 m/2 m], [bottom(i) middle(i) top(i)], 1:m);
    end
end