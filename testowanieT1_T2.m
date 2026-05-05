s = tf('s');

T2_vals = linspace(100, 10000, 50);

T1_vals = linspace(1, 100, 50);

L2 = 0;

% Preallocate
riseTime      = zeros(length(T2_vals), length(T1_vals));
overshoot     = zeros(length(T2_vals), length(T1_vals));
settlingTime  = zeros(length(T2_vals), length(T1_vals));

ITAE     = zeros(length(T2_vals), length(T1_vals));

for i = 1:length(T2_vals)
    for j = 1:length(T1_vals)

        T1 = T1_vals(j);
        G_s = 1 / (T1*s + 1);


        T2 = T2_vals(i);
        % Use real delay
        G_p = tf(1, [T2 1], 'InputDelay', L2);
        G_total = G_s * G_p;

        % PID tuning (try PI first for stability)
        C = pidtune(G_total, 'PID');

        % Closed loop
        T_cl = feedback(C * G_total, 1);

        % Get step info
        info = stepinfo(T_cl);

        riseTime(i,j)     = info.RiseTime;
        overshoot(i,j)    = info.Overshoot;
        settlingTime(i,j) = info.SettlingTime;

        t = 0:0.01:1000;   % czas symulacji (możesz dostosować)
        [y, t] = step(T_cl, t);
        e = 1 - y;

        ITAE(i,j) = trapz(t, t .*abs(e));
    end
end

figure;
imagesc(T1_vals, T2_vals, riseTime);
set(gca,'YDir','normal');
colorbar;
title('Rise Time');
xlabel('T1');
ylabel('T2 (Time Constant)');

figure;
imagesc(T1_vals, T2_vals, overshoot);
set(gca,'YDir','normal');
colorbar;
title('Overshoot (%)');
xlabel('T1');
ylabel('T2');

figure;
imagesc(T1_vals, T2_vals, settlingTime);
set(gca,'YDir','normal');
colorbar;
title('Settling Time');
xlabel('T1');
ylabel('T2');

% KASKADA
% Preallocate
riseTime_c     = zeros(length(T2_vals), length(T1_vals));
overshoot_c     = zeros(length(T2_vals), length(T1_vals));
settlingTime_c  = zeros(length(T2_vals), length(T1_vals));

ITAE_c   = zeros(length(T2_vals), length(T1_vals));

for i = 1:length(T2_vals)
    for j = 1:length(T1_vals)
        
        T1 = T1_vals(j);
        G_s = 1 / (T1*s + 1);
        
        C1 = pidtune(G_s, 'PID');
        T_inner = feedback(C1 * G_s, 1);


        T2 = T2_vals(i);
        L2 = 5;

        % Use real delay
        G_p = tf(1, [T2 1], 'InputDelay', L2);
        G_outer = T_inner * G_p;
        
        C2 = pidtune(G_outer, 'PID');
        
        % FULL SYSTEM
        T_cascade = feedback(C2 * G_outer, 1);

        % Get step info
        info = stepinfo(T_cascade);

        riseTime_c(i,j)     = info.RiseTime;
        overshoot_c(i,j)    = info.Overshoot;
        settlingTime_c(i,j) = info.SettlingTime;

        t = 0:0.01:1000;
        [y, t] = step(T_cascade, t);
        e = 1 - y;
        
        ITAE_c(i,j) = trapz(t, t .*abs(e));
    end
end

figure;
imagesc(T1_vals, T2_vals, riseTime_c);
set(gca,'YDir','normal');
colorbar;
title('Rise Time - cascade');
xlabel('T1');
ylabel('T2 (Time Constant)');

figure;
imagesc(T1_vals, T2_vals, overshoot_c);
set(gca,'YDir','normal');
colorbar;
title('Overshoot (%) - cascade');
xlabel('T1');
ylabel('T2');

figure;
imagesc(T1_vals, T2_vals, settlingTime_c);
set(gca,'YDir','normal');
colorbar;
title('Settling Time - cascade');
xlabel('T1');
ylabel('T2');

% różnica 1-punktowe vs kaskada

riseTime_diff = riseTime - riseTime_c;
overshoot_diff = overshoot - overshoot_c;
settlingTime_diff = settlingTime - settlingTime_c;

figure;
imagesc(T1_vals, T2_vals, riseTime_diff);
set(gca,'YDir','normal');

cmax = max(abs(riseTime_diff(:)));
clim([-cmax cmax]);

colormap(redblue);
colorbar;

title('Rise Time Difference (Normal - Cascade)');
xlabel('T1');
ylabel('T2');

figure;
imagesc(T1_vals, T2_vals, overshoot_diff);
set(gca,'YDir','normal');

cmax = max(abs(overshoot_diff(:)));   % <-- FIX
clim([-cmax cmax]);

colormap(redblue);
colorbar;

title('Overshoot Difference');

figure;
imagesc(T1_vals, T2_vals, settlingTime_diff);
set(gca,'YDir','normal');

cmax = max(abs(settlingTime_diff(:)));   % <-- FIX
clim([-cmax cmax]);

colormap(redblue);
colorbar;

title('Settling Time Difference');


ITAE_diff = ITAE - ITAE_c;

figure;
imagesc(T1_vals, T2_vals, ITAE_diff);
set(gca,'YDir','normal');

cmax = max(abs(ITAE_diff(:)));   % <-- FIX
clim([-cmax cmax]);

colormap(redblue);
colorbar;

title('ITAE Difference');


function cmap = redblue(m)
    if nargin < 1
        m = 256;
    end

    bottom = [0 0 1];   % blue
    middle = [1 1 1];   % white
    top    = [1 0 0];   % red

    % Interpolate
    cmap = zeros(m,3);
    for i = 1:3
        cmap(:,i) = interp1([1 m/2 m], ...
            [bottom(i) middle(i) top(i)], 1:m);
    end
end