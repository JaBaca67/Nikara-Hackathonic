from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parent
DEST = ROOT / 'Nikara_Solicitud_Demo.pdf'
GREEN = colors.HexColor('#164b38')
INK = colors.HexColor('#20352d')
GRAY = colors.HexColor('#50665c')
LINE = colors.HexColor('#b6cbbf')
WIDTH, HEIGHT = A4
LEFT = 44
FIELD_WIDTH = WIDTH - 2 * LEFT

c = canvas.Canvas(str(DEST), pagesize=A4)
c.setTitle('Nikara | Solicitud de acceso a la demo')
c.setAuthor('Nikara')
form = c.acroForm


def label(text, y):
    c.setFont('Helvetica-Bold', 10)
    c.setFillColor(INK)
    c.drawString(LEFT, y, text)


def line(text, x, y, size=9, color=GRAY):
    c.setFont('Helvetica', size)
    c.setFillColor(color)
    c.drawString(x, y, text)


def field(name, title, y, required=False, height=27, multiline=False):
    label(title + (' *' if required else ''), y)
    flags = ['required'] if required else []
    if multiline:
        flags.append('multiline')
    form.textfield(
        name=name, tooltip=title, x=LEFT, y=y - height - 9,
        width=FIELD_WIDTH, height=height, fontName='Helvetica', fontSize=10,
        borderColor=LINE, textColor=INK, fillColor=colors.white,
        borderWidth=1, forceBorder=True, fieldFlags=' '.join(flags),
        maxlen=1000 if multiline else 150,
    )


def check(name, y, lines):
    form.checkbox(
        name=name, tooltip=' '.join(lines), x=LEFT, y=y - 4,
        size=13, checked=False, buttonStyle='check', borderColor=LINE,
        textColor=GREEN, fillColor=colors.white, forceBorder=True,
        fieldFlags='required',
    )
    for index, text in enumerate(lines):
        line(text, LEFT + 23, y - index * 13, 9, INK)


c.setFillColor(GREEN)
c.rect(0, HEIGHT - 117, WIDTH, 117, fill=1, stroke=0)
c.setFillColor(colors.white)
c.setFont('Helvetica-Bold', 25)
c.drawString(LEFT, HEIGHT - 44, 'NIKARA')
c.setFont('Helvetica-Bold', 16)
c.drawString(LEFT, HEIGHT - 70, 'Solicitud de acceso a la demo')
c.setFont('Helvetica', 10)
c.drawString(LEFT, HEIGHT - 91, 'Descubre nuestra propuesta de ecoturismo. Demo disponible para Android.')

line('Completa tus datos. Revisaremos tu solicitud y te responderemos por correo.', LEFT, 705)
line('Los campos marcados con * son obligatorios.', LEFT, 690, 8)

field('nombre', 'Nombre completo', 667, required=True)
field('correo', 'Correo para recibir el acceso', 610, required=True)
line('Si usamos Drive privado, utiliza un correo vinculado a tu cuenta de Google.', LEFT, 559, 8)
field('organizacion', 'Organización o institución (opcional)', 534)

label('¿Con qué perfil te gustaría probar Nikara? *', 477)
form.choice(
    name='perfil', tooltip='Perfil del solicitante', x=LEFT, y=441,
    width=FIELD_WIDTH, height=27, fontName='Helvetica', fontSize=10,
    borderColor=LINE, textColor=INK, fillColor=colors.white,
    borderWidth=1, forceBorder=True, fieldFlags='combo required',
    options=['Selecciona una opción', 'Viajero/a', 'Guía turístico/a',
             'Emprendimiento turístico', 'Institución / evaluador/a', 'Otro'],
    value='Selecciona una opción',
)
field('dispositivo', 'Modelo del teléfono y versión de Android (opcional)', 420)
field('motivo', '¿Qué te gustaría explorar o evaluar en la demo?', 363, required=True,
      height=55, multiline=True)

check('android', 272, ['Confirmo que dispongo de un teléfono Android para instalar la APK. *'])
check('prototipo', 238, ['Entiendo que esta es una versión de prototipo para pruebas',
                        'y puede contener errores. *'])
check('contacto', 192, ['Autorizo utilizar mi nombre y correo para gestionar esta solicitud',
                       'y enviarme instrucciones de acceso a la demo. *'])

c.setStrokeColor(LINE)
c.line(LEFT, 145, WIDTH - LEFT, 145)
label('¿Qué sucede después?', 125)
line('Recibirás una confirmación de recepción. El acceso se enviará únicamente', LEFT, 106)
line('si tu solicitud es aprobada. Enviar este formulario no habilita la descarga.', LEFT, 93)
line('Botón del formulario web: Enviar solicitud', LEFT, 61, 8)

c.showPage()
c.save()
print(f'PDF creado: {DEST}')
