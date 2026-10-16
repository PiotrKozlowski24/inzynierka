s = tf('s');

K1= -5;
T1 = 17;
T2 = 31;
K2 = 1.7;


G_1 = K1/(T1*s + 1);
G_2 = K2/(T2*s + 1);
G = G_1 * G_2;

[C] = pidtune(G, 'PI');

Kc = C.Kp   % Proportional gain
Ki = C.Ki   % Integral gain

C1 = pidtune(G_1, 'P');
Kc1 = C1.Kp

T = feedback(C1*G_1, 1);

C2 = pidtune(G_2*T, 'PI');
Kc2 = C2.Kp
Ki2 = C2.Ki