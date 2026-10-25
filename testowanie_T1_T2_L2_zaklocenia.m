clc
clear

s = tf('s');
T1_vals = linspace(1, 20, 40);
T2_vals = linspace(20, 200, 40);

L2_vals = linspace(0, 60, 40);

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

% Parametry regulatorów — Single-loop PI
Kp_single = zeros(nL, nT2, nT1);
Ki_single = zeros(nL, nT2, nT1);

% Parametry regulatorów — Cascade PID
Kp_inner = zeros(nL, nT2, nT1);  % C1: P
Kp_outer = zeros(nL, nT2, nT1);  % C2: PI
Ki_outer = zeros(nL, nT2, nT1);

opts = pidtuneOptions('PhaseMargin', 60);

%% ===== Konfiguracja zakłócenia =====
dist.type      = 'noise';    % 'step' lub 'noise'
dist.location  = 'middle';  % 'input' (wejście G_1), 'middle' (między G_1 i G_2) lub 'output' (wyjście obiektu)
dist.amp       = 0.5;       % amplituda skoku
dist.t_step    = 500;       % chwila wystąpienia skoku [s]
dist.sigma     = 0.05;      % odchylenie standardowe szumu
dist.seed      = 1;         % ziarno (ten sam szum dla obu układów i wszystkich symulacji)

t_sim = 0:0.1:2000;

switch dist.type
    case 'step'
        d_sig = dist.amp * (t_sim(:) >= dist.t_step);
    case 'noise'
        rng(dist.seed);
        d_sig = dist.sigma * randn(numel(t_sim), 1);
    otherwise
        error('Nieznany typ zakłócenia: %s', dist.type);
end

% Dodatkowe macierze wyników
ITAE_d   = zeros(nL, nT2, nT1);   ITAE_d_c = zeros(nL, nT2, nT1);
IAE_d    = zeros(nL, nT2, nT1);   IAE_d_c  = zeros(nL, nT2, nT1);

fprintf('Sweeping L2 values...\n');

totalSim = nL * nT2 * nT1;
simCount = 0;

tic;


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

            % ---- Single-loop PI ----
            G_total = G_s * G_p;
            C = pidtune(G_total, 'PI', opts);
            T_cl = feedback(C * G_total, 1);


            % ---- Zakłócenie: układ jednopętlowy ----
            switch dist.location
                case 'input'    % d dodane do sygnału sterującego u (wejście G_s)
                    Gd = feedback(G_total, C);                  % G_s*G_p/(1+C*G_s*G_p)
                case 'middle'   % d dodane między G_s i G_p (wejście G_p)
                    Gd = G_p * feedback(1, C * G_total);        % G_p/(1+C*G_s*G_p)
                case 'output'   % d dodane do wyjścia obiektu
                    Gd = feedback(1, C * G_total);              % 1/(1+C*G_s*G_p)
            end
            yd = lsim(Gd, d_sig, t_sim);
            ITAE_d(k,i,j) = trapz(t_sim, t_sim(:) .* abs(yd));
            IAE_d(k,i,j)  = trapz(t_sim, abs(yd));

            info = stepinfo(T_cl);
            riseTime(k,i,j)     = info.RiseTime;
            overshoot(k,i,j)    = info.Overshoot;
            settlingTime(k,i,j) = info.SettlingTime;
            Kp_single(k,i,j) = C.Kp;
            Ki_single(k,i,j) = C.Ki;

            [y, t] = step(T_cl, t_sim);
            ITAE(k,i,j) = trapz(t, t .* abs(1 - y));

            % ---- Cascade PID ----
            C1 = pidtune(G_s, 'P', opts);
            T_inner = feedback(C1 * G_s, 1);

            G_outer = T_inner * G_p;
            C2 = pidtune(G_outer, 'PI', opts);
            T_cascade = feedback(C2 * G_outer, 1);


            % ---- Zakłócenie: układ kaskadowy ----
            switch dist.location
                case 'input'    % d w pętli wewnętrznej (wejście G_s)
                    Gd_c = G_p * feedback(G_s, C1) * feedback(1, C2 * G_outer);
                case 'middle'   % d między G_s i G_p, za punktem pomiaru y1
                    Gd_c = G_p * feedback(1, C2 * G_outer);
                case 'output'
                    Gd_c = feedback(1, C2 * G_outer);
            end
            ydc = lsim(Gd_c, d_sig, t_sim);
            ITAE_d_c(k,i,j) = trapz(t_sim, t_sim(:) .* abs(ydc));
            IAE_d_c(k,i,j)  = trapz(t_sim, abs(ydc));

            info_c = stepinfo(T_cascade);
            riseTime_c(k,i,j)     = info_c.RiseTime;
            overshoot_c(k,i,j)    = info_c.Overshoot;
            settlingTime_c(k,i,j) = info_c.SettlingTime;
            Kp_inner(k,i,j) = C1.Kp;
            Kp_outer(k,i,j) = C2.Kp;
            Ki_outer(k,i,j) = C2.Ki;

            [yc, tc] = step(T_cascade, t_sim);
            ITAE_c(k,i,j) = trapz(tc, tc .* abs(1 - yc));

            % =========================================================
            % Progress
            % =========================================================

            simCount = simCount + 1;

            elapsed = toc;
            avgTime = elapsed / simCount;
            remaining = totalSim - simCount;
            eta = remaining * avgTime;

            fprintf('\rProgress: %6.2f %% | %d / %d | Remaining: %d | ETA: %s', ...
                100 * simCount / totalSim, ...
                simCount, ...
                totalSim, ...
                remaining, ...
                datestr(seconds(eta), 'HH:MM:SS'));
        end
    end
end

%% Save results
save('simulation_results_noise_middle.mat', ...
    'riseTime', 'overshoot', 'settlingTime', 'ITAE', ...
    'riseTime_c', 'overshoot_c', 'settlingTime_c', 'ITAE_c', ...
    'Kp_single', 'Ki_single', ...
    'Kp_inner', 'Kp_outer', 'Ki_outer', ...
    'ITAE_d', 'ITAE_d_c', 'IAE_d', 'IAE_d_c', 'dist', ...
    'T1_vals', 'T2_vals', 'L2_vals');

fprintf('Results saved to simulation_results.mat\n');


%%

load('simulation_results.mat');