"""Execute the actual template functions in JXA, with small DOM doubles.

Not a browser/layout/accessibility test. No npm, network, or installed dependencies.
"""
import json
from pathlib import Path
import subprocess
import unittest


@unittest.skipUnless(Path("/usr/bin/osascript").exists(), "JXA runtime unavailable (macOS only)")
class AnamneseHtmlRuntimeTests(unittest.TestCase):
    def js(self, scenario):
        template = (Path(__file__).resolve().parents[1] / "templates/anamnese.html").read_text()
        functions = template[template.index("var respostasYn"):template.index("renderForm(TEMPLATE);")]
        fixture = (Path(__file__).parent / "anamnese_dom_fixture.js").read_text()
        result = subprocess.run(["/usr/bin/osascript", "-l", "JavaScript", "-"],
                                input=functions + fixture + scenario, text=True,
                                capture_output=True, timeout=10, check=True)
        return json.loads(result.stdout)

    def test_yesno_sem_selecao_e_obrigatorio_bloqueia(self):
        result = self.js('''
var markup = renderPergunta({id:'risco', tipo:'yesno', required:true});
questions = [question('risco', 'yesno', true)];
JSON.stringify({selected: markup.indexOf('selecionado') >= 0,
                answers: coletar(), error: validar()});
''')
        self.assertFalse(result["selected"])
        self.assertEqual(result["answers"], {})
        self.assertTrue(result["error"])

    def test_escolha_nao_explicita_coletada_e_valida(self):
        result = self.js('''
renderPergunta({id:'risco', tipo:'yesno', required:true});
questions = [question('risco', 'yesno', true)];
toggleYn(button(questions[0]), false);
JSON.stringify({answers: coletar(), error: validar()});
''')
        self.assertEqual(result, {"answers": {"risco": False}, "error": None})

    def test_range_nao_respondido_ate_evento_inclusive_zero(self):
        result = self.js('''
var markup = renderPergunta({id:'escala', tipo:'scale', min:0, max:10, required:true});
var input = control('5');
questions = [question('escala', 'scale', true, input)];
ranges = [input];
renderForm({secoes:[]});
var before = {answers:coletar(), error:validar()};
input.value = '0'; input.events.input();
JSON.stringify({before:before, after:{answers:coletar(), error:validar()},
                unanswered:markup.indexOf('Não respondido') >= 0});
''')
        self.assertEqual(result["before"]["answers"], {})
        self.assertTrue(result["before"]["error"])
        self.assertTrue(result["unanswered"])
        self.assertEqual(result["after"], {"answers": {"escala": 0}, "error": None})

    def test_opcionais_intocados_nao_coletados(self):
        result = self.js('''
questions = [question('texto','text',false,control('  ')),
 question('lista','checklist',false), question('radio','radio',false),
 question('yn','yesno',false), question('scale','scale',false,control('5'))];
JSON.stringify({answers:coletar(), error:validar()});
''')
        self.assertEqual(result, {"answers": {}, "error": None})

    def test_condicional_so_coletado_quando_sim(self):
        result = self.js('''
var parent = question('medicacao','yesno',false);
var child = question('quais','text',true,control('sintetica'),parent);
questions = [parent,child];
toggleYn(button(parent), true);
var yes = coletar();
toggleYn(button(parent), false);
JSON.stringify({yes:yes, no:coletar(), error:validar()});
''')
        self.assertEqual(result["yes"], {"medicacao": True, "quais": "sintetica"})
        self.assertEqual(result["no"], {"medicacao": False})
        self.assertIsNone(result["error"])

    def test_condicional_required_renderizado_e_validado(self):
        result = self.js('''
var markup = renderCondicional({id:'quais',tipo:'text',required:true});
var parent = question('medicacao','yesno',false);
questions = [parent,question('quais','text',true,control(''),parent)];
toggleYn(button(parent), true);
JSON.stringify({required:markup.indexOf('data-required="1"') >= 0, error:validar()});
''')
        self.assertTrue(result["required"])
        self.assertTrue(result["error"])
