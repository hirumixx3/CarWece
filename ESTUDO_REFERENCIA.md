# Referência de projeto — hirumisu

Fonte primária consultada: manual original de **Hot Wheels: Beat That!**, versão PS2, publicado com o jogo pela Activision. Foram lidas as páginas de controles, pilotagem, HUD, armas, carros, eventos e progressão, a partir da digitalização abaixo.

[Manual original PS2, 12 páginas](https://www.videogamemanual.com/PS2/Hot%20Wheels-%20Beat%20That%21%20%28USA%29.pdf)

O manual separa direção, acelerador, freio/ré, drift, arma e supercarga. Ele descreve ganho de energia por derrapagem, vácuo e saltos, além de impulsos, atalhos e armamento com efeitos diferentes. Os eventos incluem corrida, eliminatória, combate por acertos e torneio; a progressão combina colocação com objetivos. Esses pontos servem como referência de comportamento, sem usar código, modelos, pistas, áudio ou arte extraídos do original.

## Aplicação nesta versão

| Decisão para CarWece | Implementação própria |
| --- | --- |
| O jogador faz as curvas | Corpo com posição/orientação/velocidade; não recebe o controlador da IA. |
| Ambiente participa da corrida | Chão dirigível, móveis/blocos sólidos, rampas e sinalização de checkpoints. |
| Pilotagem exige escolha | Raio de giro limitado pela velocidade, frenagem, ré e drift. |
| Percurso precisa ser completado | Portais sequenciais e chegada por cruzamento interpolado. |

A entrega atual tem 12 carros, 12 percursos e 3 modos, com modelagem própria. O manual orientou as decisões acima; o projeto mantém sua identidade e seu escopo de versão de teste.


## Identificação dos carros da v0.5

As referências abaixo identificam os modelos e suas famílias de desenho. As malhas deste projeto são estilizações próprias; os valores de desempenho foram equilibrados para o jogo.

- [VeilSide — RX-7 Fortune, base FD3S](https://www.veilsidejpn.com/en/rx7_fortune.php).
- [Mitsubishi — história dos carros, Lancer Evolution IX](https://www.mitsubishi-motors.com/en/company/history/car/).
- [Nissan Heritage — Skyline GT-R V-spec II, BNR34](https://www.nissan-global.com/EN/HERITAGE_COLLECTION/280_skyline_gt-r_v-spec_ii.html).
- [Nissan Heritage — Fairlady Z, Z33](https://www.nissan-global.com/EN/HERITAGE_COLLECTION/284_fairlady_z_version_st.html).
- [Toyota — lançamento do Supra de 1993](https://global.toyota/en/detail/7868203).
- [Honda — história do NSX de 1990](https://global.honda/en/heritage/episodes/1990thensx.html).
- [Subaru — catálogo do Impreza 22B-STi de 1998](https://ucar.subaru.jp/php/catalog/grade.php?cat_id=4501993).
- [Honda — gerações Type R, Civic EK9 de 1997](https://global.honda/en/stories/048.html).

Características usadas na estilização: kit largo e bicolor no RX-7, sedã e asa alta no Evo, quatro lanternas redondas no R34, faróis alongados e cabine arqueada no Z33, asa curva no Supra, perfil baixo e teto escuro no NSX, rodas douradas e scoop no 22B, hatch curto no EK9. Não há fotos, malhas ou áudio desses sites empacotados no aplicativo.

## Identificação dos quatro carros da v0.6

- [Nissan — lançamento oficial Silvia S15, 19/01/1999](https://global.nissannews.com/en/releases/19990119-e_presskit).
- [BMW Group Classic — M3 Coupé E46](https://www.bmwgroup-classic.com/en/models/bmw-classics/product-description-page.ad-843-1.bmw-m3-coupe-e46.html).
- [Porsche — 911 GT3 RS, apresentação de 2022](https://newsroom.porsche.com/en/2022/products/porsche-911-gt3-rs-world-premiere-29177.html).
- [Lamborghini — Huracán Tecnica](https://www.lamborghini.com/en-en/history/huracan-tecnica).

As fontes orientam identificação, silhueta e sinais de desenho. Desempenho, custo, gates e física são definidos para este jogo, sem pretensão de simular a ficha técnica ou fabricar uma réplica CAD.
