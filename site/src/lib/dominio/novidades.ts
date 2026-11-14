import { fmt, nomeMateria } from "./formato";
import type { Historico } from "./tipos";

/** Notas que não existiam antes e apareceram agora (ex.: "N2 de Compiladores: 8,5"). */
export function notasNovas(antes: Historico, depois: Historico): string[] {
  const out: string[] = [];
  for (const s of depois.semestres) {
    const antigo = antes.semestres.find((x) => x.codigo === s.codigo);
    if (!antigo) continue;
    const porChave = new Map(antigo.disciplinas.map((d) => [d.chave, d]));
    for (const d of s.disciplinas) {
      const a = porChave.get(d.chave);
      if (!a) continue;
      const nome = nomeMateria(d.nome).nome;
      d.notas.forEach((nota, i) => {
        if (a.notas[i] === null && nota !== null) {
          out.push(`N${i + 1} de ${nome}: ${fmt(nota)}`);
        }
      });
      if (a.nota4 == null && d.nota4 != null) {
        out.push(`N4 de ${nome}: ${fmt(d.nota4)}`);
      }
    }
  }
  return out;
}
