
clear; clc; close all;
s = tf('s');

%% Parametry obiektow
T1 = 1;
T2 = 200;
K1 = -16;
K2 = 1.7;
d2 = 1;

G1 = K1/(T1*s + 1);
G2 = tf(K2, [T2 1], 'InputDelay', d2);

%% Parametry do strojenia
alpha_values = [0.1 0.2 0.5 1 1.5 2 3 5 8 10 20];

% Czas symulacji do obliczenia ITAE
t = (0:0.1:500)';

% Wektory ITAE
ITAE_cascade = zeros(size(alpha_values));
ITAE_single = zeros(size(alpha_values));

K_total = K1*K2;

%% Strojenie kaskady + obliczanie ITAE
figure;
hold on;

for i = 1:length(alpha_values)

    alpha = alpha_values(i);

    lambda1 = d2*alpha;
    lambda2 = d2*alpha;

    % Regulator wewnetrzny P
    Kc_inner = T1/(K1*lambda1);
    C_inner = Kc_inner;

    % Regulator zewnetrzny PI
    Kc_outer = T2/(K2*(lambda2 + d2));
    Ti_outer = T2 + lambda1 + ...
        d2^2/(2*(lambda2 + d2));

    C_outer = Kc_outer*(1 + 1/(Ti_outer*s));

    % Petla wewnetrzna i zewnetrzna
    T_inner = feedback(C_inner*G1, 1);
    T_cascade = feedback(C_outer*G2*T_inner, 1);

    % Odpowiedz skokowa
    y = squeeze(step(T_cascade, t));
    y = y(:);

    % ITAE dla skoku jednostkowego
    e = 1 - y;
    ITAE_cascade(i) = trapz(t, t.*abs(e));

    plot(t, y, 'DisplayName', ...
        sprintf('\\alpha = %g', alpha));
end

grid on;
title('Odpowiedzi skokowe - regulacja kaskadowa');
xlabel('Czas [s]');
ylabel('Wyjscie y(t)');
legend('Location', 'best');
hold off;

%% Strojenie single loop PI + obliczanie ITAE
figure;
hold on;

for i = 1:length(alpha_values)

    alpha = alpha_values(i);
    lambda = alpha*d2;

    Kc_single = T2/(K_total*(lambda + d2));
    Ti_single = T2;

    C_PI = Kc_single*(1 + 1/(Ti_single*s));

    T_single = feedback(C_PI*G1*G2, 1);

    % Odpowiedz skokowa
    y = squeeze(step(T_single, t));
    y = y(:);

    % ITAE dla skoku jednostkowego
    e = 1 - y;
    ITAE_single(i) = trapz(t, t.*abs(e));

    plot(t, y, 'DisplayName', ...
        sprintf('\\alpha = %g', alpha));
end

grid on;
title('Single loop PI - przyblizenie FOPDT');
xlabel('Czas [s]');
ylabel('Wyjscie y(t)');
legend('Location', 'best');
hold off;

%% Wyniki ITAE i optymalna alfa
[ITAE_min_cascade, idx_cascade] = min(ITAE_cascade);
alpha_opt_cascade = alpha_values(idx_cascade);

[ITAE_min_single, idx_single] = min(ITAE_single);
alpha_opt_single = alpha_values(idx_single);

Wyniki = table(alpha_values(:), ITAE_cascade(:), ...
    ITAE_single(:), ...
    'VariableNames', {'Alpha', 'ITAE_Kaskada', ...
    'ITAE_SingleLoop'});

disp(' ');
disp('=== POROWNANIE WSKAZNIKA ITAE ===');
disp(Wyniki);

fprintf('\nKASKADA:\n');
fprintf('Optymalna alfa = %g\n', alpha_opt_cascade);
fprintf('Minimalne ITAE = %.6f\n', ITAE_min_cascade);

fprintf('\nSINGLE LOOP PI:\n');
fprintf('Optymalna alfa = %g\n', alpha_opt_single);
fprintf('Minimalne ITAE = %.6f\n', ITAE_min_single);

%% Wykres ITAE w funkcji alfy
figure;
plot(alpha_values, ITAE_cascade, '-o', ...
    'LineWidth', 1.5, 'MarkerSize', 7);
hold on;
plot(alpha_values, ITAE_single, '-s', ...
    'LineWidth', 1.5, 'MarkerSize', 7);
grid on;
xlabel('\alpha');
ylabel('ITAE');
title('ITAE w funkcji parametru \alpha');
legend('Kaskada', 'Single loop PI', ...
    'Location', 'best');
hold off;

%% Porownanie: kaskada i single loop dla wybranego alpha

lambda1 = alpha_opt_cascade*d2;
lambda2 = alpha_opt_cascade*d2;
lambda = alpha_opt_single*d2;

% Kaskada
Kc_inner = T1/(K1*lambda1);
C_inner = Kc_inner;
T_inner = feedback(C_inner*G1, 1);

Kc_outer = T2/(K2*(lambda2 + d2));
Ti_outer = T2 + lambda1 + ...
    d2^2/(2*(lambda2 + d2));
C_outer = Kc_outer*(1 + 1/(Ti_outer*s));

T_cascade = feedback(C_outer*G2*T_inner, 1);

% Single loop PI
 
    Kc_single = T2/(K_total*(lambda+d2));
    Ti_single = min([T2 4*(lambda+d2)]);

    C_PI = Kc_single*(1 + 1/(Ti_single*s));


T_single = feedback(C_PI*G1*G2, 1);

figure;
step(T_cascade, T_single);
stepinfo(T_cascade)
stepinfo(T_single)
grid on;
title('Porownanie: kaskada i single loop PI');
xlabel('Czas [s]');
ylabel('Wyjscie y(t)');
legend('Kaskada', 'Single loop PI', 'Location', 'best');
