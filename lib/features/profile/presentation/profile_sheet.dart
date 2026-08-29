import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../domain/user_profile.dart';

class ProfileSheet extends ConsumerStatefulWidget {
  const ProfileSheet({super.key, required this.initial});
  final UserProfile initial;

  @override
  ConsumerState<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends ConsumerState<ProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _weight;
  late final TextEditingController _height;
  late final TextEditingController _age;
  late String _sex;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.name);
    _weight = TextEditingController(text: widget.initial.weightKg.toStringAsFixed(1));
    _height = TextEditingController(text: widget.initial.heightCm.toStringAsFixed(0));
    _age = TextEditingController(text: widget.initial.age.toString());
    _sex = widget.initial.sex;
  }

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    _height.dispose();
    _age.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('Perfil corporal', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('Usado localmente para estimar calorias e personalizar suas métricas.'),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Informe um nome' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _weight,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Peso (kg)'),
                        validator: _positiveNumber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _height,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Altura (cm)'),
                        validator: _positiveNumber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _age,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Idade'),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < 10 || n > 100 ? 'Idade inválida' : null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _sex,
                  decoration: const InputDecoration(labelText: 'Sexo biológico (opcional para referência)'),
                  items: const [
                    DropdownMenuItem(value: 'not_informed', child: Text('Prefiro não informar')),
                    DropdownMenuItem(value: 'male', child: Text('Masculino')),
                    DropdownMenuItem(value: 'female', child: Text('Feminino')),
                  ],
                  onChanged: (v) => setState(() => _sex = v ?? 'not_informed'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(_saving ? 'Salvando...' : 'Salvar perfil'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _positiveNumber(String? value) {
    final normalized = value?.replaceAll(',', '.');
    final number = double.tryParse(normalized ?? '');
    return number == null || number <= 0 ? 'Valor inválido' : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final profile = UserProfile(
      name: _name.text.trim(),
      weightKg: double.parse(_weight.text.replaceAll(',', '.')),
      heightCm: double.parse(_height.text.replaceAll(',', '.')),
      age: int.parse(_age.text),
      sex: _sex,
    );
    await ref.read(userRepositoryProvider).save(profile);
    ref.invalidate(userProfileProvider);
    if (mounted) Navigator.pop(context);
  }
}
