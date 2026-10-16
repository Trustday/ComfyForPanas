# Personaje: descripción para su LoRA

Copia este archivo junto a las imágenes del personaje (por ejemplo `D:\lora\Aiko\Aiko_descripcion.md`) y completa lo que va después de cada flecha (→).
Escribe en español; en la columna de etiquetas va lo mismo en inglés, como en Danbooru, que es lo que entiende Illustrious.

## Identidad

- Nombre →
- Palabra clave (minúsculas, sin espacios, que no sea una palabra real; ej. `aikochan`) →
- ¿Original o de algún anime? → *(si es de un anime conocido, prueba primero si Illustrious ya lo dibuja por su nombre: quizás no necesitas LoRA)*
- Edad → *(siempre adulta o adulto; un número ayuda a que no salga aniñado)*

## Rasgos fijos: los tiene en TODAS las imágenes

Estos van en **"Rasgos fijos"** al preparar el paquete: se quitan de las etiquetas para que los aprenda la palabra clave.

| Rasgo | Cómo es → | Etiquetas en inglés → |
|---|---|---|
| Piel | → | → *(ej. dark skin, dark-skinned female, pale skin)* |
| Ojos | → | → *(ej. yellow eyes, heterochromia)* |
| Color y largo del pelo | → | → *(ej. black hair, long hair)* |
| Cuerpo | → | → *(ej. large breasts, wide hips, muscular female)* |
| Marcas: lunares, cicatrices, tatuajes | → | → *(ej. mole under eye, scar on face)* |
| Rasgos no humanos: orejas, cola, cuernos | → | → *(ej. fox ears, fox tail)* |

## Rasgos que cambian: se dejan etiquetados

No van en "Rasgos fijos". Así después se pueden pedir en el prompt.

- Peinados (ej. fleco recto = `blunt bangs`, fleco al lado = `swept bangs`, cola de caballo = `ponytail`, trenza = `braid`) →
- Ropa típica (ej. uniforme escolar, armadura, ropa deportiva) →
- Accesorios que lleva a veces (aros, lentes, sombrero) →
- Expresión habitual (ej. sonrisa pícara = `smug`, sonrisa dulce = `gentle smile`) →

## Lo que el LoRA NUNCA debe hacer

- → *(ej. verse menor de edad, cambiar el color de ojos)*

## Revisión de las imágenes (antes de preparar el paquete)

- [ ] Entre 20 y 35 imágenes, todas del mismo personaje (si un amigo duda en decir "es ella/él", fuera).
- [ ] Sin texto, firmas ni marcas de agua (la estrella de Gemini, abajo a la derecha, también cuenta). Se recortan o se borran.
- [ ] Sin otras personas en la imagen.
- [ ] Idealmente 1024 px o más por lado; las de 512 enseñan desenfoque.
- [ ] Variedad: cara de cerca, medio cuerpo, cuerpo entero, de frente, perfil y espalda. Si falta un ángulo, complétalo con Qwen ("Cambio grande") desde tu mejor imagen.
- [ ] Como máximo 2 o 3 imágenes casi iguales (misma pose y mismo fondo): si no, el LoRA se "pega" a esa pose o fondo.
- [ ] Nunca imágenes hechas con Illustrious sin LoRA: no saben dibujar a tu personaje.
